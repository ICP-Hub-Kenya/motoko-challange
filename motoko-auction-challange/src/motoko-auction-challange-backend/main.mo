import List "mo:base/List";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat"; 
import Time "mo:base/Time";
import Int "mo:base/Int";

actor {
  //item in the auction
  type Item = {
    title : Text;
    description : Text;
    image : Blob;
  };

//bid in auction
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


//function to create a bid on an auction
  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
     let auction = findAuction(auctionId);  // Find the auction by ID

    // Check if the auction is still active (has remaining time)
    if (auction.remainingTime == 0) {
      Debug.trap("Auction has ended");  // If time is up, trap the execution
    };

    // Ensure the new bid is higher than the previous bid
    switch (List.get(auction.bidHistory, 0)) {
      case null { };  // First bid, no need to check
      case (?prevBid) {
        if (price <= prevBid.price) {
          Debug.trap("Bid must be higher than the current highest bid");  // Reject the bid if not higher
        };
      };
    };
  

    // Create the new bid with the price and time
    let newBid : Bid = {
       price;                   
       time = Int.abs(Time.now()) ;  
      originator = message.caller;  // Set the bidder's principal
    };

    // Add the new bid to the auction's bid history
    auction.bidHistory := List.push(newBid, auction.bidHistory);
  };
};