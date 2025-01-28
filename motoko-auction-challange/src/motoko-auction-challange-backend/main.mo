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
    idCounter += 1;  // Increment the auction ID counter
    let newAuction : Auction = {
      id = idCounter;           // Set the auction ID
      item = item;              // Set the auction item
      var bidHistory = List.nil<Bid>();  // Initialize an empty bid history
      var remainingTime = duration;     // Set the auction duration (remaining time)
    };
    auctions := List.push(newAuction, auctions);  // Add the new auction to the list of active auctions
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