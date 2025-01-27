import Result "mo:base/Result";
import List "mo:base/List";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

actor {
  type Error = {
    #InvalidPrice;
    #AuctionNotFound;
    #AuctionNotActive;
    #BidTooLow;
    #InvalidDuration;
  };

  type AuctionStatus = {
    #active;
    #closed;
    #cancelled;
  };

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
    var status : AuctionStatus;
    var winningBid : ?Bid;
    reservePrice : Nat;  // Minimum price that must be met
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    status : AuctionStatus;
    winningBid : ?Bid;
    reservePrice : Nat;
  };

  // Type to represent a bid with its associated auction
  type BidWithAuction = {
    auctionId : AuctionId;
    item : Item;
    bid : Bid;
    auctionStatus : AuctionStatus;
  };

  func findAuction(auctionId : AuctionId) : Result.Result<Auction, Error> {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch (result) {
      case null #err(#AuctionNotFound);
      case (?auction) #ok(auction);
    };
  };

  /*
   * Stable Storage Implementation
   * ----------------------------
   * The following variables use the `stable` keyword to ensure data persistence across canister upgrades:
   * 1. auctions: Stores all auction data including items, bid histories, and timing
   * 2. idCounter: Maintains unique auction IDs across upgrades
   */
  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;

  // Helper function to create a new auction
  private func createAuction(item : Item, duration : Nat, reservePrice : Nat) : Auction {
    idCounter += 1;
    {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      var status = #active;
      var winningBid = null;
      reservePrice = reservePrice;
    }
  };

  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async Result.Result<AuctionId, Error> {
    if (duration == 0) {
      return #err(#InvalidDuration);
    };
    if (reservePrice == 0) {
      return #err(#InvalidPrice);
    };
    let auction = createAuction(item, duration, reservePrice);
    auctions := List.push(auction, auctions);
    #ok(auction.id)
  };

  /*
   * Timer Implementation for Auction Management
   * ----------------------------------------
   * Automatically updates auction status and determines winners
   * when the remaining time reaches zero.
   */
  private func closeAuction(auction : Auction) {
    if (auction.remainingTime == 0 and auction.status == #active) {
      auction.status := #closed;
      // Determine winning bid (last bid in history)
      let firstBid = List.get(auction.bidHistory, 0);
      // Only set winning bid if it meets reserve price
      switch (firstBid) {
        case null { /* No bids */ };
        case (?bid) {
          if (bid.price >= auction.reservePrice) {
            auction.winningBid := ?bid;
          };
        };
      };
    };
  };

  public func updateAuctionTimes() : async () {
    auctions := List.map<Auction, Auction>(
      auctions,
      func (auction) {
        if (auction.remainingTime > 0 and auction.status == #active) {
          auction.remainingTime -= 1;
          if (auction.remainingTime == 0) {
            closeAuction(auction);
          };
        };
        auction
      }
    );
  };

  // Initialize timer for periodic auction updates
  private let auctionTimer = Timer.recurringTimer<system>(
    #seconds(60), // Check every minute
    func() : async () {
      await updateAuctionTimes();
      // Close expired auctions
      for (auction in List.toArray(auctions).vals()) {
        closeAuction(auction);
      };
    }
  );

  public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Error> {
    switch (findAuction(auctionId)) {
      case (#err(e)) { #err(e) };
      case (#ok(auction)) {
        #ok({
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
          status = auction.status;
          winningBid = auction.winningBid;
          reservePrice = auction.reservePrice;
        })
      };
    };
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Error> {
    switch (findAuction(auctionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(auction)) {
        if (auction.status != #active) {
          return #err(#AuctionNotActive);
        };
        if (auction.remainingTime == 0) {
          return #err(#AuctionNotActive);
        };
        
        // Check if bid meets minimum requirements
        let firstBid = List.get(auction.bidHistory, 0);
        switch (firstBid) {
          case null { 
            if (price < auction.reservePrice) {
              return #err(#BidTooLow);
            };
          };
          case (?prevBid) {
            if (price <= prevBid.price) {
              return #err(#BidTooLow);
            };
          };
        };

        let newBid : Bid = {
          price = price;
          time = Time.now();
          originator = message.caller;
        };

        auction.bidHistory := List.push(newBid, auction.bidHistory);
        #ok()
      };
    };
  };

  /*
   * Active Auctions Retrieval
   * ------------------------
   * This query function returns a list of all active auctions (remaining time > 0).
   * Returns an array of AuctionDetails containing:
   * - Item information (title, description, image)
   * - Bid history
   * - Remaining time
   * The results are filtered to only include auctions with remainingTime > 0
   */
  public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(
      auctions,
      func (auction) { auction.remainingTime > 0 and auction.status == #active }
    );
    List.toArray(
      List.map<Auction, AuctionDetails>(
        activeAuctions,
        func (auction) {
          {
            item = auction.item;
            bidHistory = List.toArray(List.reverse(auction.bidHistory));
            remainingTime = auction.remainingTime;
            status = auction.status;
            winningBid = auction.winningBid;
            reservePrice = auction.reservePrice;
          }
        }
      )
    )
  };

  // Query function to get completed auctions
  public query func getCompletedAuctions() : async [AuctionDetails] {
    let completedAuctions = List.filter<Auction>(
      auctions,
      func (auction) { auction.status == #closed }
    );
    List.toArray(
      List.map<Auction, AuctionDetails>(
        completedAuctions,
        func (auction) {
          {
            item = auction.item;
            bidHistory = List.toArray(List.reverse(auction.bidHistory));
            remainingTime = auction.remainingTime;
            status = auction.status;
            winningBid = auction.winningBid;
            reservePrice = auction.reservePrice;
          }
        }
      )
    )
  };

  public shared query (message) func getUserBidHistory() : async [BidWithAuction] {
    let caller = message.caller;
    
    // Helper to find user bids in an auction
    func getUserBidsFromAuction(auction : Auction) : [BidWithAuction] {
      let userBids = List.filter<Bid>(
        auction.bidHistory,
        func(bid) { bid.originator == caller }
      );
      
      Array.map<Bid, BidWithAuction>(
        List.toArray(userBids),
        func(bid) {
          {
            auctionId = auction.id;
            item = auction.item;
            bid = bid;
            auctionStatus = auction.status;
          }
        }
      );
    };

    // Get bids from all auctions and flatten the result
    let allBids = List.map<Auction, [BidWithAuction]>(
      auctions,
      getUserBidsFromAuction
    );
    
    Array.flatten<BidWithAuction>(List.toArray(allBids))
  };

  // Query function to get total number of auctions
  public query func getTotalAuctions() : async Nat {
    List.size(auctions)
  };
}