import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";

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
    var isActive : Bool;
    var status : Text;
    reservePrice : Nat;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    isActive : Bool;
    status : Text;
    reservePrice : Nat;
  };

  // UserBidHistory defined to store the auction ID and the bid details of a user.

  type UserBidHistory = {
    auctionId : Nat;
    bid : Bid;
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

  // A function to create new auction and add it to the auctions stable variable.

  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async () {
    let auction : Auction = {
      id = idCounter;
      item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      var isActive = true;
      var status = "Active";
      reservePrice = reservePrice;
    };
    auctions := List.append(List.fromArray([auction]), auctions);
    idCounter += 1;
  };

  // getAuctionDetails function to get the details of an auction includng the bid history
  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    { 
      item = auction.item; 
      bidHistory; 
      remainingTime = auction.remainingTime;
      isActive = auction.isActive;
      status = auction.status;
      reservePrice = auction.reservePrice;
    }
  };

  // makeBid function that adds new bid to the auction's bid history.

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Text {
    let auction = findAuction(auctionId); // Retrieves the auction by its ID 

    if (not auction.isActive) {
      return "Auction is not active";
    };

    if (price < auction.reservePrice) {
      return "Bid price is less than the reserve price";
    };

    if (auction.remainingTime == 0) {
      return "Auction has ended";
    };



    let newBid : Bid = {
      price;
      time = Int.abs(Time.now());
      originator = message.caller;
    };
    auction.bidHistory := List.append(List.fromArray([newBid]), auction.bidHistory);
    return "Bid successful";
  };

  // Public function that allows users to retrieve a list of all active auctions(those whose remaining time is greater than zero)

  public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(auctions, func auction = auction.remainingTime > 0);
    List.toArray(List.map<Auction, AuctionDetails>(activeAuctions, func auction {
      let bidHistory = List.toArray(List.reverse(auction.bidHistory));
      {
        item = auction.item;
        bidHistory;
        remainingTime = auction.remainingTime;
        isActive = auction.isActive;
        status = auction.status;
        reservePrice = auction.reservePrice;
      }
    }));
  };

  // function to check and close the auctions

  func checkAndCloseAuctions() {
    auctions := List.map<Auction, Auction>(auctions, func(auction) {
      
      if (auction.remainingTime > 0) {
        auction.remainingTime := Nat.sub(auction.remainingTime,
          if (auction.remainingTime >= 60) 60 else auction.remainingTime); // Decrease remaining time by 60 seconds
      };

      if (auction.remainingTime == 0 and auction.isActive) {
        auction.isActive := false;

        // Determining the winning bid
        let winningBid = List.get(auction.bidHistory, 0);
        switch (winningBid) {
          case (null) {
            auction.status := "No one won the auction";
          };
          case (?bid) {
            if (bid.price >= auction.reservePrice) {
              auction.status := "Highest bid meets the reserve price, item sold";
            } else {
              auction.status := "Highest bid does not meet the reserve price, item not sold";
            }
          }
        };
      };
      auction
    });
  };

  // Setting up a periodic timer to call the checkAndCloseAuctions function every minute

  system func timer(setTimer : Nat64 -> ()) : async () {
    checkAndCloseAuctions();
    setTimer(60_000_000_000); // Set timer to 60 seconds (in nanoseconds)
  };

  // Function to get the bid history of a user across all the auctions. Iterates through all the auctions and their bid histories to collect bids made by a specific user.

  public query func getUserBidHistory(user : Principal) : async [UserBidHistory] {
    var userBids = List.nil<UserBidHistory>();

    for (auction in List.toIter(auctions)) {
      for (bid in List.toIter(auction.bidHistory)) {
        if (bid.originator == user) {
          userBids := List.append(userBids, List.make({
            auctionId = auction.id;
            bid;
          }));
        };
      };
    };

    List.toArray(userBids);
  };
}

