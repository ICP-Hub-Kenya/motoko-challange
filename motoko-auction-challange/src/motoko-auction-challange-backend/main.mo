import List "mo:base/List";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
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

/// Function to find an auction by ID
  func findAuction(auctionId : AuctionId) : ?Auction {
    List.find<Auction>(auctions, func auction = auction.id == auctionId);
  };

  /// Stable storage (converted between upgrades)

  stable var auctionArray : [Auction]= [];
  stable var idCounter: Nat = 0;

  /// Transient list (converted from array on upgrade)
   var auctions : List.List<Auction> = List.fromArray(auctionArray);

 /// Creates a new auction and stores it
  public func newAuction(item : Item, duration : Nat) : async AuctionId {
     let auctionId = idCounter;
     idCounter += 1;

    let newAuction : Auction = {
      id = auctionId;
      item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
    };

    auctions := List.push(newAuction, auctions);
    return auctionId;
  };

/// Retrieve auction details
  public query func getAuctionDetails(auctionId : AuctionId) : async ?AuctionDetails {
    switch (findAuction(auctionId)) {
      case (?auction){
         let bidHistory = List.toArray(List.reverse(auction.bidHistory));
          return ?{
            item = auction.item; 
            bidHistory; 
            remainingTime = auction.remainingTime 
          };
      };
      case null return null;
    };
  };

 /// Convert `auctions` list to `auctionArray` before upgrades

   system func preupgrade() {
    auctionArray := List.toArray(auctions);
  };

  /// Convert `auctionArray` back to `auctions` list after upgrades
  system func postupgrade() {
    auctions := List.fromArray(auctionArray);
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
    // Implementation here
  };
}