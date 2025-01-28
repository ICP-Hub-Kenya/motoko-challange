import List "mo:base/List";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Timer "mo:base/Timer";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

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
  type AuctionId = Nat;
  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    var isActive : Bool;
    var winningBid : ?Bid;
    reservePrice : Nat;
    owner : Principal;
  };
  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    isActive : Bool;
    winningBid : ?Bid;
    reservePrice : Nat;
    owner : Principal;
  };

  // Find auction by ID
  func findAuction(auctionId : AuctionId) : Auction {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch (result) {
      case null Debug.trap("Inexistent id");
      case (?auction) auction;
    };
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;

  // Create new auction
  public shared(msg) func createAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
    idCounter += 1;
    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      var isActive = true;
      var winningBid = null;
      reservePrice = reservePrice;
      owner = msg.caller;
    };
    auctions := List.push(newAuction, auctions);
    idCounter
  };

  // Bid
  public shared(msg) func placeBid(auctionId : AuctionId, bidPrice : Nat) : async Text {
    let auction = findAuction(auctionId);
    
    if (not auction.isActive) {
      return "Auction is closed";
    };

    if (auction.remainingTime == 0) {
      return "Auction time has expired";
    };

    switch (List.get(auction.bidHistory, 0)) {
      case null {
        if (bidPrice < auction.reservePrice) {
          return "Bid below reserve price";
        };
      };
      case (?highestBid) {
        if (bidPrice <= highestBid.price) {
          return "Bid must be higher than current highest bid";
        };
      };
    };

    let newBid : Bid = {
      price = bidPrice;
      time = Time.now();
      originator = msg.caller;
    };

    auction.bidHistory := List.push(newBid, auction.bidHistory);
    "Bid placed successfully"
  };

  // Get auction details
  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    {
      item = auction.item;
      bidHistory = List.toArray(List.reverse(auction.bidHistory));
      remainingTime = auction.remainingTime;
      isActive = auction.isActive;
      winningBid = auction.winningBid;
      reservePrice = auction.reservePrice;
      owner = auction.owner;
    }
  };

  // List of Auctions
  public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(
      auctions,
      func (auction) { auction.isActive and auction.remainingTime > 0 }
    );

    List.toArray(List.map<Auction, AuctionDetails>(
      activeAuctions,
      func (auction) {
        {
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
          isActive = auction.isActive;
          winningBid = auction.winningBid;
          reservePrice = auction.reservePrice;
          owner = auction.owner;
        }
      }
    ))
  };

  // Get user's bid history
  public query func getUserBidHistory(user : Principal) : async [Bid] {
    var userBids : List.List<Bid> = List.nil();
    
    for (auction in List.toArray(auctions).vals()) {
      let userAuctionBids = List.filter(auction.bidHistory, func(bid : Bid) : Bool {
        bid.originator == user
      });
      userBids := List.append(userAuctionBids, userBids);
    };
    
    List.toArray(userBids)
  };

  // Close auction and determine winner
  private func closeAuction(auction : Auction) {
    if (auction.remainingTime == 0 and auction.isActive) {
      auction.isActive := false;
      let highestBid = List.get(auction.bidHistory, 0);
      switch (highestBid) {
        case null { /* No bids */ };
        case (?bid) {
          if (bid.price >= auction.reservePrice) {
            auction.winningBid := ?bid;
          };
        };
      };
    };
  };

  // Update auction times
  public func updateAuctionTimes() : async () {
    auctions := List.map(auctions, func (auction : Auction) : Auction {
      if (auction.remainingTime > 0 and auction.isActive) {
        auction.remainingTime -= 1;
        if (auction.remainingTime == 0) {
          closeAuction(auction);
        };
      };
      auction
    });
  };

  private let auctionTimer = Timer.recurringTimer(
    #seconds(60),
    func() : async () {
      await updateAuctionTimes();
    }
  );
}
