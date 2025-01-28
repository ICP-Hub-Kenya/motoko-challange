import List "mo:base/List";
import Principal "mo:base/Principal";
import Time "mo:base/Time";

module {
    public type Item = {
        title : Text;
        description : Text;
        image : Blob;
    };

    public type Bid = {
        price : Nat;
        time : Nat;
        originator : Principal;
    };

    public type AuctionId = Nat;

    public type Auction = {
        id : AuctionId;
        item : Item;
        var bidHistory : List.List<Bid>;
        var remainingTime : Nat;
        var closingTime : Time.Time;
        var reservePrice : ?Nat;
        var winningBid : ?Bid;
        owner : Principal;
    };

    public type AuctionDetails = {
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
        reservePrice : ?Nat;
        winningBid : ?Bid;
    };

    public type AuctionError = {
        #NoAuctionWithId : AuctionId;
        #CallerNotTheOwner;
        #AuctionClosed;
        #BidTooLow : { highestBid : Nat };
    };
};
