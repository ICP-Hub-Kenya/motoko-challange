import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Timer "mo:base/Timer";
import _Option "mo:base/Option";
import Debug "mo:base/Debug";
import _Int "mo:base/Int";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Error "mo:base/Error";

actor class AuctionSystem() {
    // Constants for validation
    private let MIN_AUCTION_DURATION_NS = 5 * 60 * 1000000000; // 5 minutes
    private let MAX_AUCTION_DURATION_NS = 30 * 24 * 60 * 60 * 1000000000; // 30 days
    private let MAX_BIDS_PER_USER = 1000;

    
    type AuctionId = Nat;
    
    type Bid = {
        bidder: Principal;
        amount: Nat;
        timestamp: Time.Time;
    };

    type AuctionStatus = {
        #active;
        #ended;
        #cancelled;
        #reserveNotMet;
    };

    type AuctionEvent = {
        eventType: {
            #created;
            #bidPlaced;
            #ended;
            #cancelled;
        };
        timestamp: Time.Time;
        details: Text;
    };

    type Auction = {
        id: AuctionId;
        creator: Principal;
        itemName: Text;
        description: Text;
        startPrice: Nat;
        reservePrice: Nat;
        endTime: Time.Time;
        highestBid: ?Bid;
        status: AuctionStatus;
        events: [AuctionEvent];  // Audit trail
        lastUpdateTime: Time.Time;
    };

    // Stable storage
    private stable var nextAuctionId: AuctionId = 0;
    private stable var auctionEntries: [(AuctionId, Auction)] = [];
    private stable var userBidEntries: [(Principal, [Bid])] = [];

    // Runtime state
    private var auctions = HashMap.HashMap<Nat, Auction>(0, Nat.equal, Hash.hash);  
    private var userBids = HashMap.HashMap<Principal, Buffer.Buffer<Bid>>(0, Principal.equal, Principal.hash);

    // Logging
    private func logEvent(auction: Auction, eventType: AuctionEvent) : Auction {
        let events = Array.append(auction.events, [eventType]);
        {auction with events = events; lastUpdateTime = Time.now()}
    };

    // Input validation
    private func validateAuctionInputs(
        startPrice: Nat,
        reservePrice: Nat,
        duration: Nat
    ) : {#ok : (); #err : Text} {
        if (startPrice == 0) {
            return #err("Start price must be greater than 0");
        };
        if (reservePrice < startPrice) {
            return #err("Reserve price must be greater than or equal to start price");
        };
        if (duration < MIN_AUCTION_DURATION_NS) {
            return #err("Auction duration too short");
        };
        if (duration > MAX_AUCTION_DURATION_NS) {
            return #err("Auction duration too long");
        };
        #ok()
    };

    // System upgrade handlers with error recovery
    system func preupgrade() {
        auctionEntries := Iter.toArray(auctions.entries());
        userBidEntries := Array.map<(Principal, Buffer.Buffer<Bid>), (Principal, [Bid])>(
            Iter.toArray(userBids.entries()),
            func((principal, buffer)) : (Principal, [Bid]) {
                (principal, Buffer.toArray(buffer))
            }
        );
    };

    system func postupgrade() {
        for ((id, auction) in auctionEntries.vals()) {
            auctions.put(id, auction);
        };
        
        for ((principal, bids) in userBidEntries.vals()) {
            let bidBuffer = Buffer.Buffer<Bid>(bids.size());
            for (bid in bids.vals()) {
                if (bidBuffer.size() < MAX_BIDS_PER_USER) {
                    bidBuffer.add(bid);
                };
            };
            userBids.put(principal, bidBuffer);
        };
    };

    // Create new auction with validation
    public shared(msg) func createAuction(
        itemName: Text,
        description: Text,
        startPrice: Nat,
        reservePrice: Nat,
        duration: Nat
    ) : async {#ok : AuctionId; #err : Text} {
        // Input validation
        switch(validateAuctionInputs(startPrice, reservePrice, duration)) {
            case (#err(msg)) { return #err(msg) };
            case (#ok()) {};
        };

        let currentTime = Time.now();
        let auction: Auction = {
            id = nextAuctionId;
            creator = msg.caller;
            itemName;
            description;
            startPrice;
            reservePrice;
            endTime = currentTime + duration;
            highestBid = null;
            status = #active;
            events = [{
                eventType = #created;
                timestamp = currentTime;
                details = "Auction created";
            }];
            lastUpdateTime = currentTime;
        };
        
        auctions.put(nextAuctionId, auction);
        nextAuctionId += 1;
        
        // Set timer with error handling
       try {
         // Set a timer to automatically close the auction after the specified duration.
    // The <system> capability is required because setting a timer involves system-level operations.
            ignore Timer.setTimer<system>(
                #nanoseconds(duration),// The duration after which the auction should be closed, specified in nanoseconds.
                func() : async () {
                    await closeAuction(auction.id);
                }
            );
        } catch (e) {
            Debug.print("Timer setting failed: " # Error.message(e));
            // Fallback: Set status to indicate manual checking needed
            auctions.put(auction.id, logEvent(auction, {
                eventType = #created;
                timestamp = Time.now();
                details = "Timer setup failed - manual monitoring required";
            }));
        };

        #ok(auction.id)
        };
    
      // Place bid with enhanced validation   
       public shared(msg) func placeBid(auctionId: AuctionId, amount: Nat) : async {#ok; #err : Text} {
        switch (auctions.get(auctionId)) {
            case (null) { #err("Auction not found") };
            case (?auction) {
                if (auction.status != #active) {
                    return #err("Auction is not active");
                };
                
                let currentTime = Time.now();
                if (currentTime >= auction.endTime) {
                    return #err("Auction has ended");
                };

                if (amount < auction.reservePrice) {
                    return #err("Bid is below reserve price of " # debug_show(auction.reservePrice));
                };

                switch (auction.highestBid) {
                    case (?currentBid) {
                        if (amount <= currentBid.amount) {
                            return #err("Bid must be higher than current bid of " # debug_show(currentBid.amount));
                        };
                    };
                    case (null) {
                        if (amount < auction.startPrice) {
                            return #err("Bid must be at least the starting price of " # debug_show(auction.startPrice));
                        };
                    };
                };

                let bid: Bid = {
                    bidder = msg.caller;
                    amount = amount;
                    timestamp = currentTime;
                };

                // Update auction with new bid and event
                let updatedAuction = logEvent(
                    {auction with highestBid = ?bid},
                    {
                        eventType = #bidPlaced;
                        timestamp = currentTime;
                        details = "Bid placed: " # debug_show(amount);
                    }
                );
                auctions.put(auctionId, updatedAuction);

                // Update user bid history with size limit
                switch (userBids.get(msg.caller)) {
                    case (null) {
                        let bidBuffer = Buffer.Buffer<Bid>(1);
                        bidBuffer.add(bid);
                        userBids.put(msg.caller, bidBuffer);
                    };
                    case (?bidBuffer) {
                        if (bidBuffer.size() < MAX_BIDS_PER_USER) {
                            bidBuffer.add(bid);
                        } else {
                            // Remove oldest bid and add new one
                            ignore bidBuffer.remove(0);
                            bidBuffer.add(bid);
                        };
                    };
                };

                #ok
            };
        };
    };    

    // Get active auctions with pagination
    public query func getActiveAuctions(offset: Nat, limit: Nat) : async [Auction] {
        let currentTime = Time.now();
        let activeAuctions = Array.filter<Auction>(
            Iter.toArray(auctions.vals()),
            func (a: Auction) : Bool {
                a.status == #active and a.endTime > currentTime
            }
        );
        
        let start = Nat.min(offset, activeAuctions.size());
        let end = Nat.min(offset + limit, activeAuctions.size());
        Array.subArray(activeAuctions, start, end - start)
    };

    // Get user bid history with pagination
    public query(msg) func getUserBidHistory(offset: Nat, limit: Nat) : async [Bid] {
        switch (userBids.get(msg.caller)) {
            case (null) { [] };
            case (?bidBuffer) {
                let bids = Buffer.toArray(bidBuffer);
                let start = Nat.min(offset, bids.size());
                let end = Nat.min(offset + limit, bids.size());
                Array.subArray(bids, start, Nat.max(end, start) - start)
            };
        }
    };
    // Close auction with enhanced error handling
    private func closeAuction(auctionId: AuctionId) : async () {
        switch (auctions.get(auctionId)) {
            case (null) { return };
            case (?auction) {
                if (auction.status != #active) {
                    return;
                };

                let finalStatus = switch (auction.highestBid) {
                    case (null) { #cancelled };
                    case (?bid) {
                        if (bid.amount >= auction.reservePrice) {
                            #ended
                        } else {
                            #reserveNotMet
                        };
                    };
                };

                let updatedAuction = logEvent(
                    {auction with status = finalStatus},
                    {
                        eventType = #ended;
                        timestamp = Time.now();
                        details = "Auction closed with status: " # debug_show(finalStatus);
                    }
                );
                auctions.put(auctionId, updatedAuction);
            };
        };
    };

    // For testing: Get auction details
    public query func getAuction(id: AuctionId) : async ?Auction {
        auctions.get(id)
    };
}