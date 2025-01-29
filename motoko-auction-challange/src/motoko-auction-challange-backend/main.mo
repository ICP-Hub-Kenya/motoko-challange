import Debug "mo:base/Debug";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
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

  type AuctionStatus = {
    isActive : Bool;
  };

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    var bidCount : Nat;
    var status : AuctionStatus;
  };

  type AuctionOverview = {
    id : AuctionId;
    item : Item;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    highestBid : ?Bid;
    bidCount : Nat;
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
    let id = idCounter;
    idCounter += 1;
    let bidHistory = List.nil<Bid>();
    let newAuction = { id; item; var bidHistory; var remainingTime = duration; var bidCount = 0; var status = { isActive = true } };
    auctions := List.push(newAuction, auctions);
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    let highestBid = getHighestBid(auction);
    return { 
      item = auction.item; 
      bidHistory; 
      remainingTime = auction.remainingTime;
      highestBid; 
      bidCount = auction.bidCount
    };
  };

// 1. Function to retrieve auction data. 
  public query func getOverviewList() : async [AuctionOverview] {
    func getOverview(auction : Auction) : AuctionOverview = {
      id = auction.id;
      item = auction.item;
    };
      let overviewList = List.map<Auction, AuctionOverview>(auctions, getOverview);
      List.toArray(List.reverse(overviewList));
    };


//2. Function to allow users get all active auctions 
  public func getActiveAuctions() : async [AuctionOverview] {
    let activeAuctions = List.filter(auctions, func (auction : Auction) : Bool {
        auction.remainingTime > 0 & auction.status.isActive
    });
    
    let overviews = List.map(activeAuctions, func (auction : Auction) : AuctionOverview {
        {
            id = auction.id;
            item = auction.item;
        }
    });
  
    return List.toArray(overviews);
  };


//3. Periodic timer to get the winning bid by looping through the bidding history when time closes to get the winning bid. 
  
  func tick() : async () {
    for (auction in List.toIter(auctions)) {
      if (auction.remainingTime > 0) {
        auction.remainingTime -= 1;
        if (auction.remainingTime == 0) {
          await closeAuction(auction.id);
        }
      };
    };
  };

  func closeAuction(auctionId : AuctionId) : async () {
    let auction = findAuction(auctionId);
    var winningBid : ?Bid = null;
    
    for (bid in List.toIter(auction.bidHistory)) {
      switch (winningBid) {
        case null { winningBid := ?bid };
        case (?currentWinningBid) {
          if (bid.price > currentWinningBid.price) {
            winningBid := ?bid;
          };
        };
      };
    };

  switch (winningBid) {
    case null { 
      Debug.print("Auction " # debug_show(auctionId) # " closed without any bids.");
    };
    case (?winner) {
      Debug.print("Auction " # debug_show(auctionId) # " closed. Winner: " # 
                  debug_show(winner.originator) # " with bid: " # 
                  debug_show(winner.price));
      
    };
  };
};

let timer = Timer.recurringTimer(#seconds 1, tick);


//4. Function to make a bid by compairing the minimum price to the bidding price. If the bidding price is higher than the minimum price,
// the bid is accepted. 
  func minimumPrice(auction : Auction) : Nat {
    switch (auction.bidHistory) {
      case null 1;
      case (?(lastBid, _)) lastBid.price + 1;
    };
  };

  public func makeBid(auctionId : AuctionId, bidPrice : Nat) : async @Result {
    let auction = findAuction(auctionId);
    let newBid = { price = bidPrice; time = getCurrentTime(); originator = msg.caller };
    if (auction.remainingTime == 0 | not auction.status.isActive) {
        return #err("Auction is not active or has ended.");
    };
    // Proceed with placing the bid
    auction.bidHistory := List.push(newBid, auction.bidHistory);
    auction.bidCount += 1;
    return #ok(());
  };


//5. Retrieve bidding history in order. 
  public query func getHistory(auctionId : AuctionId) : async [Bid] {
    let auction = findAuction(auctionId);
    return List.toArray(auction.bidHistory);
  };

// New function to get the highest bid for an auction
  func getHighestBid(auction : Auction) : ?Bid {
    var highestBid : ?Bid = null;
    for (bid in List.toIter(auction.bidHistory)) {
      switch (highestBid) {
        case null { highestBid := ?bid };
        case (?currentHighestBid) {
          if (bid.price > currentHighestBid.price) {
            highestBid := ?bid;
          };
        };
      };
    };
    return highestBid;
  };
}