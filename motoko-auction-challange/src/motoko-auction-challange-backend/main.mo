import List "mo:base/List";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";  
import Nat64 "mo:base/Nat64";

actor {
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

    type AuctionStatus = {
        #Active;
        #Closed;
        #NotSold;
    };

    type AuctionId = Nat;

    type AuctionData = {
        id : AuctionId;
        item : Item;
        creator : Principal;
        bidHistory : List.List<Bid>;
        remainingTime : Nat;
        reservePrice : Nat;
        status : AuctionStatus;
    };

    type Auction = {
        id : AuctionId;
        item : Item;
        creator : Principal;
        var bidHistory : List.List<Bid>;
        var remainingTime : Nat;
        reservePrice : Nat;
        var status : AuctionStatus;
    };

    type AuctionDetails = {
        id : AuctionId;
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
        status : AuctionStatus;
        reservePrice : Nat;
    };

    // Stable storage
    stable var auctions = List.nil<Auction>();
    stable var idCounter = 0;
    
    // Timer duration in nanoseconds (1 minute for testing)
    let TIMER_INTERVAL : Nat64 = 60_000_000_000;

    // Helper functions
    func findAuction(auctionId : AuctionId) : ?Auction {
        List.find<Auction>(auctions, func auction = auction.id == auctionId);
    };

    func isAuctionActive(auction : Auction) : Bool {
        auction.remainingTime > 0 and auction.status == #Active;
    };

    // Create new auction
    public shared(msg) func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
        idCounter += 1;
        
        // Create immutable auction data first
        let auctionData : AuctionData = {
            id = idCounter;
            item = item;
            creator = msg.caller;
            bidHistory = List.nil<Bid>();
            remainingTime = duration;
            reservePrice = reservePrice;
            status = #Active;
        };
        
        // Create mutable auction object
        let newAuction : Auction = {
            id = auctionData.id;
            item = auctionData.item;
            creator = auctionData.creator;
            var bidHistory = auctionData.bidHistory;
            var remainingTime = auctionData.remainingTime;
            reservePrice = auctionData.reservePrice;
            var status = auctionData.status;
        };
        
        auctions := List.push<Auction>(newAuction, auctions);
        idCounter;
    };

    // Get active auctions
    public query func getActiveAuctions() : async [AuctionDetails] {
        let activeAuctions = List.filter<Auction>(auctions, isAuctionActive);
        Array.map<Auction, AuctionDetails>(
            List.toArray(activeAuctions),
            func (auction) {
                {
                    id = auction.id;
                    item = auction.item;
                    bidHistory = List.toArray(List.reverse(auction.bidHistory));
                    remainingTime = auction.remainingTime;
                    status = auction.status;
                    reservePrice = auction.reservePrice;
                }
            }
        );
    };

    // Make a bid
    public shared(msg) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch (findAuction(auctionId)) {
            case null {
                #err("Auction not found");
            };
            case (?auction) {
                if (not isAuctionActive(auction)) {
                    return #err("Auction is not active");
                };

                let currentHighestBid = List.get(auction.bidHistory, 0);
                switch (currentHighestBid) {
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
                #ok();
            };
        };
    };

    // Get user's bidding history
    public shared(msg) func getUserBidHistory() : async [AuctionDetails] {
        let userAuctions = List.filter<Auction>(
            auctions,
            func (auction) {
                List.some<Bid>(
                    auction.bidHistory,
                    func (bid) { bid.originator == msg.caller }
                );
            }
        );
        Array.map<Auction, AuctionDetails>(
            List.toArray(userAuctions),
            func (auction) {
                {
                    id = auction.id;
                    item = auction.item;
                    bidHistory = List.toArray(List.reverse(auction.bidHistory));
                    remainingTime = auction.remainingTime;
                    status = auction.status;
                    reservePrice = auction.reservePrice;
                }
            }
        );
    };

    // Timer callback to update auction status
    system func timer(setTimer : Nat64 -> ()) : async () {
        // Set up periodic timer
        setTimer(TIMER_INTERVAL);
        
        // Update auctions
        auctions := List.map<Auction, Auction>(
            auctions,
            func (auction) {
                if (isAuctionActive(auction)) {
                    if (auction.remainingTime <= 1) {
                        // Close auction
                        let highestBid = List.get(auction.bidHistory, 0);
                        switch (highestBid) {
                            case (?bid) {
                                if (bid.price >= auction.reservePrice) {
                                    auction.status := #Closed;
                                } else {
                                    auction.status := #NotSold;
                                };
                            };
                            case null {
                                auction.status := #NotSold;
                            };
                        };
                        auction.remainingTime := 0;
                    } else {
                        auction.remainingTime -= 1;
                    };
                };
                auction;
            }
        );
    };
};