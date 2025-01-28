import List "mo:base/List";
// import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
// import Option "mo:base/Option";
import Result "mo:base/Result";
import Int "mo:base/Int";

actor {
    type Item = {
        title : Text;
        description : Text;
        image : Blob;
    };

    type Bid = {
        price : Nat;
        time : Nat;
        originator : Principal;
    };

    type AuctionId = Nat;

    // Enhanced Auction type with reserve price and status
    type Auction = {
        id : AuctionId;
        item : Item;
        var bidHistory : List.List<Bid>;
        var remainingTime : Nat;
        reservePrice : Nat;
        var status : AuctionStatus;
        creator : Principal;
    };

    type AuctionStatus = {
        #Active;
        #Closed;
        #Cancelled;
        #ReservePriceNotMet;
    };

    type AuctionDetails = {
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
        status : AuctionStatus;
        reservePrice : Nat;
    };

    // Stable storage
    stable var auctions = List.nil<Auction>();
    stable var idCounter = 0;
    
    // User bidding history mapping (Principal -> List of bids)
    stable var userBidHistory = List.nil<(Principal, List.List<(AuctionId, Bid)>)>();

    // Initialize timer in a stable way
    private var auctionTimer : Timer.TimerId = 0;

    // Helper function to find an auction
    func findAuction(auctionId : AuctionId) : Result.Result<Auction, Text> {
        let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
        switch (result) {
            case null #err("Auction not found");
            case (?auction) #ok(auction);
        };
    };

    // Create a new auction
    public shared({ caller }) func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
        idCounter += 1;
        let newAuction : Auction = {
            id = idCounter;
            item = item;
            var bidHistory = List.nil<Bid>();
            var remainingTime = duration;
            reservePrice = reservePrice;
            var status = #Active;
            creator = caller;
        };
        auctions := List.push(newAuction, auctions);
        idCounter
    };

    // Get auction details
    public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Text> {
        switch(findAuction(auctionId)) {
            case (#err(msg)) #err(msg);
            case (#ok(auction)) {
                #ok({
                    item = auction.item;
                    bidHistory = List.toArray(List.reverse(auction.bidHistory));
                    remainingTime = auction.remainingTime;
                    status = auction.status;
                    reservePrice = auction.reservePrice;
                })
            };
        }
    };

    // Place a bid
    public shared({ caller }) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch(findAuction(auctionId)) {
            case (#err(msg)) #err(msg);
            case (#ok(auction)) {
                if (auction.status != #Active) {
                    return #err("Auction is not active");
                };

                if (auction.remainingTime == 0) {
                    return #err("Auction time has expired");
                };

                switch (List.get(auction.bidHistory, 0)) {
                    case (?prevBid) {
                        if (price <= prevBid.price) {
                            return #err("Bid must be higher than current highest bid");
                        };
                    };
                    case null {};
                };

                let newBid : Bid = {
                    price = price;
                    time = Int.abs(Time.now());
                    originator = caller;
                };

                auction.bidHistory := List.push(newBid, auction.bidHistory);
                updateUserBidHistory(caller, auctionId, newBid);
                #ok(())
            };
        }
    };

    // 2. public function that allows users to retrieve a list of all active auctions (those with remaining time > 0).
    public query func getActiveAuctions() : async [AuctionDetails] {
        let activeAuctions = List.filter(auctions, func (a : Auction) : Bool {
            a.remainingTime > 0 and a.status == #Active
        });
        Array.map(List.toArray(activeAuctions), func (auction : Auction) : AuctionDetails {
            {
                item = auction.item;
                bidHistory = List.toArray(List.reverse(auction.bidHistory));
                remainingTime = auction.remainingTime;
                status = auction.status;
                reservePrice = auction.reservePrice;
            }
        })
    };

    // 5. function that allows users to retrieve their bidding history across all auctions
    public shared({ caller }) func getUserBidHistory() : async [(AuctionId, Bid)] {
        switch (List.find(userBidHistory, func (entry : (Principal, List.List<(AuctionId, Bid)>)) : Bool {
            Principal.equal(entry.0, caller)
        })) {
            case (?entry) List.toArray(entry.1);
            case null [];
        }
    };

    // Helper function to update user bid history
    private func updateUserBidHistory(user : Principal, auctionId : AuctionId, bid : Bid) {
        let userEntry = List.find(userBidHistory, func (entry : (Principal, List.List<(AuctionId, Bid)>)) : Bool {
            Principal.equal(entry.0, user)
        });
        
        switch (userEntry) {
            case (?entry) {
                let updatedHistory = List.push((auctionId, bid), entry.1);

                userBidHistory := List.map<(Principal, List.List<(AuctionId, Bid)>), (Principal, List.List<(AuctionId, Bid)>)>(userBidHistory, func (e : (Principal, List.List<(AuctionId, Bid)>)) : (Principal, List.List<(AuctionId, Bid)>) {
                    if (Principal.equal(e.0, user)) {
                        (user, updatedHistory)
                    } else {
                        e
                    }
                });
            };
            case null {
                userBidHistory := List.push((user, List.make((auctionId, bid))), userBidHistory);
            };
        };
    };

    // Timer callback to update auctions
    private func updateAuctions() : async () {
        auctions := List.map(auctions, func (auction : Auction) : Auction {
            if (auction.status == #Active and auction.remainingTime > 0) {
                auction.remainingTime -= 1;
                
                // 3. periodic timer that automatically closes auctions when their remaining time reaches zero
                if (auction.remainingTime == 0) {
                    let highestBid = List.get(auction.bidHistory, 0);
                    switch (highestBid) {
                        case (?bid) {

                            // 4. feature that allows the auction creator to set a reserve price. If the highest bid doesn't meet the reserve price when the auction closes, the item should not be sold
                            if (bid.price >= auction.reservePrice) {
                                auction.status := #Closed;
                            } else {
                                auction.status := #ReservePriceNotMet;
                            };
                        };
                        case null {
                            auction.status := #Cancelled;
                        };
                    };
                };
            };
            auction
        });
    };

    // System upgrade hooks with proper timer management
    system func preupgrade() {
        Timer.cancelTimer(auctionTimer);
    };

    system func postupgrade() {
        auctionTimer := Timer.recurringTimer<system>(#seconds(60), updateAuctions);
    };
}