import List "mo:base/List";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";

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

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
  };

  func findAuction(auctionId : AuctionId) : Auction {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch (result) {
      case null Debug.trap("Inexistent id");
      case (?auction) auction;
    };
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;

  public func newAuction(item : Item, duration : Nat) : async Result.Result<(), Text> {
    // Implementation here
    if (item.title == "") {
      return #err("Title cannot be empty");
    };

    if (item.description == "") {
      return #err("Description cannot be empty");
    };

    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
    };

    auctions := List.push(newAuction, auctions);
    idCounter += 1;

    #ok(());
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    {
      item = auction.item;
      bidHistory;
      remainingTime = auction.remainingTime;
    };
  };

  public query func getAllAuctions() : async [AuctionDetails] {
    let auctionList = List.toArray(auctions);

    Array.map<Auction, AuctionDetails>(auctionList, func(auction) { { item = auction.item; bidHistory = List.toArray(List.reverse(auction.bidHistory)); remainingTime = auction.remainingTime } });
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
    // Implementation here
  };
};
