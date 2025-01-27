import List "mo:base/List";
import Debug "mo:base/Debug";

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

  public func newAuction(item : Item, duration : Nat) : async () {
    // Implementation here
    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
    };

    auctions := List.push(newAuction, auctions);
    idCounter += 1;
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    { 
      item = auction.item; 
      bidHistory; 
      remainingTime = auction.remainingTime 
    }
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
    // Implementation here
  };
}