import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

actor {
    // Types
    type Item = {
        title : Text;
        description : Text;
        image : Blob;
    };

    type Bid = {
        price : Nat;
        time : Int;
        originator : Principal;
    };

    type AuctionId = Nat;

    type Auction = {
        id : AuctionId;
        item : Item;
        var bidHistory : List.List<Bid>;
        var remainingTime : Nat;
        var reservePrice : ?Nat;
        creator : Principal;
        var isActive : Bool;
    };

    type AuctionDetails = {
        id : AuctionId;
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
        reservePrice : ?Nat;
        creator : Principal;
        isActive : Bool;
    };

    type BidInfo = {
        auctionId : AuctionId;
        item : Item;
        bid : Bid;
    };

    // Stable state
    stable var auctions = List.nil<Auction>();
    stable var idCounter = 0;

    // Helper functions
    func findAuction(auctionId : AuctionId) : ?Auction {
        List.find<Auction>(auctions, func(a) { a.id == auctionId });
    };

    func getHighestBid(bidHistory : List.List<Bid>) : ?Bid {
        List.last(bidHistory);
    };

    // Comparison function for sorting bids
    func compareBidInfo(a : BidInfo, b : BidInfo) : Order.Order {
        if (a.bid.time > b.bid.time) { #less }
        else if (a.bid.time < b.bid.time) { #greater }
        else { #equal };
    };

    // Main functions
    public shared(msg) func newAuction(item : Item, duration : Nat) : async AuctionId {
        let auction : Auction = {
            id = idCounter;
            item = item;
            var bidHistory = List.nil<Bid>();
            var remainingTime = duration;
            var reservePrice = null;
            creator = msg.caller;
            var isActive = true;
        };
        
        auctions := List.push(auction, auctions);
        idCounter += 1;
        auction.id;
    };

    public shared(msg) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch (findAuction(auctionId)) {
            case null { #err("Auction not found") };
            case (?auction) {
                if (not auction.isActive) {
                    return #err("Auction is not active");
                };
                
                if (auction.remainingTime == 0) {
                    return #err("Auction has ended");
                };

                switch (getHighestBid(auction.bidHistory)) {
                    case (?highestBid) {
                        if (price <= highestBid.price) {
                            return #err("Bid must be higher than current highest bid");
                        };
                    };
                    case null {};
                };

                let newBid = {
                    price;
                    time = Time.now();
                    originator = msg.caller;
                };

                auction.bidHistory := List.push(newBid, auction.bidHistory);
                #ok(());
            };
        };
    };

    public query func getActiveAuctions() : async [AuctionDetails] {
        let activeAuctions = List.filter<Auction>(auctions, func(a) { 
            a.isActive and a.remainingTime > 0 
        });
        
        Array.map<Auction, AuctionDetails>(
            List.toArray(activeAuctions),
            func(a) {
                {
                    id = a.id;
                    item = a.item;
                    bidHistory = List.toArray(List.reverse(a.bidHistory));
                    remainingTime = a.remainingTime;
                    reservePrice = a.reservePrice;
                    creator = a.creator;
                    isActive = a.isActive;
                }
            }
        );
    };

    public func updateAuctionTimers() : async () {
        auctions := List.map<Auction, Auction>(
            auctions,
            func(a) {
                if (a.isActive and a.remainingTime > 0) {
                    a.remainingTime -= 1;
                    if (a.remainingTime == 0) {
                        switch (getHighestBid(a.bidHistory)) {
                            case (?highestBid) {
                                switch (a.reservePrice) {
                                    case (?minPrice) {
                                        if (highestBid.price >= minPrice) {
                                            a.isActive := false;
                                        };
                                    };
                                    case null {
                                        a.isActive := false;
                                    };
                                };
                            };
                            case null {
                                a.isActive := false;
                            };
                        };
                    };
                };
                a;
            }
        );
    };

    public shared(msg) func addReservePrice(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch (findAuction(auctionId)) {
            case null { #err("Auction not found") };
            case (?auction) {
                if (msg.caller != auction.creator) {
                    return #err("Only auction creator can set reserve price");
                };
                
                if (not auction.isActive) {
                    return #err("Cannot modify inactive auction");
                };
                
                auction.reservePrice := ?price;
                #ok(());
            };
        };
    };

    public query func getUserBidHistory(user : Principal) : async [BidInfo] {
        var bidHistory = Buffer.Buffer<BidInfo>(0);
        
        for (auction in List.toArray(auctions).vals()) {
            for (bid in List.toArray(auction.bidHistory).vals()) {
                if (Principal.equal(bid.originator, user)) {
                    bidHistory.add({
                        auctionId = auction.id;
                        item = auction.item;
                        bid = bid;
                    });
                };
            };
        };
        
        // Convert to array and sort manually
        let unsortedArray = Buffer.toArray(bidHistory);
        let sorted = Array.sort(unsortedArray, compareBidInfo);
        sorted;
    };

    public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Text> {
        switch (findAuction(auctionId)) {
            case null { #err("Auction not found") };
            case (?auction) {
                #ok({
                    id = auction.id;
                    item = auction.item;
                    bidHistory = List.toArray(List.reverse(auction.bidHistory));
                    remainingTime = auction.remainingTime;
                    reservePrice = auction.reservePrice;
                    creator = auction.creator;
                    isActive = auction.isActive;
                });
            };
        };
    };
};