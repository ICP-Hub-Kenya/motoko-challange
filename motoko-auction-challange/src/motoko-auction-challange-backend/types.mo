import Principal "mo:base/Principal";
import List "mo:base/List";

module {
    public type Item = {
        title : Text;
        description : Text;
        image : Blob;
    };

    public type Bid = {
        price : Nat;
        time : Int;
        originator : Principal;
    };

    public type AuctionId = Nat;

    public type Auction = {
        id : AuctionId;
        item : Item;
        var bidHistory : List.List<Bid>;
        var remainingTime : Nat;
        var reservePrice : ?Nat;
        creator : Principal;
        var isActive : Bool;
    };

    public type AuctionDetails = {
        id : AuctionId;
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
        reservePrice : ?Nat;
        creator : Principal;
        isActive : Bool;
    };

    public type BidInfo = {
        auctionId : AuctionId;
        item : Item;
        bid : Bid;
    };
};
