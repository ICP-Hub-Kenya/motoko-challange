import List "mo:base/List";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
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
    minBidIncrement : Nat;  // Added minimum bid increment
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    isActive : Bool;
    winningBid : ?Bid;
    reservePrice : Nat;
    owner : Principal;
    minBidIncrement : Nat; // Include min bid increment in details
  };

  // Enhanced error handling using Result
  type Error = {
    #AuctionNotFound;
    #AuctionClosed;
    #BidTooLow;
    #BidTooSmall;
    #InvalidBid;
    #AuctionEnded;
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;

  // Improved auction finder with Result
  private func findAuction(auctionId : AuctionId) : Result.Result<Auction, Error> {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch(result) {
      case null { #err(#AuctionNotFound) };
      case (?auction) { #ok(auction) };
    };
  };

  // Create new auction
  public shared(msg) func createAuction(item : Item, duration : Nat, reservePrice : Nat, minBidIncrement : Nat) : async Result.Result<AuctionId, Error> {
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
      minBidIncrement = minBidIncrement;
    };
    auctions := List.push(newAuction, auctions);
    #ok(idCounter)
  };

  // Place a bid
  public shared(msg) func placeBid(auctionId : AuctionId, bidPrice : Nat) : async Result.Result<Text, Error> {
    switch (findAuction(auctionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(auction)) {
        if (not auction.isActive) {
          return #err(#AuctionClosed);
        };

        if (auction.remainingTime == 0) {
          return #err(#AuctionClosed);
        };


        switch (List.get(auction.bidHistory, 0)) {
          case null { if (bidPrice < auction.reservePrice) { return #err(#BidTooLow); }};
          case (?highestBid) { 
            if (bidPrice < (highestBid.price + auction.minBidIncrement)) {
              return #err(#BidTooLow);
            }
          };
        };

        let newBid : Bid = {
          price = bidPrice;
          time = Time.now();
          originator = msg.caller;
        };

        auction.bidHistory := List.push(newBid, auction.bidHistory);

        // Extend auction time if bid placed in last 5 minutes
        if (auction.remainingTime < 300) {
          auction.remainingTime := 300; // Reset to 5 minutes
        };

        #ok("Bid placed successfully");
      };
    };
  };

  // Get auction details
  public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Error> {
    switch (findAuction(auctionId)) {
      case (#err(e)) { return #err(e) };
      case (#ok(auction)) {
        let bidHistory = List.toArray(List.reverse(auction.bidHistory));
        #ok({
          item = auction.item;
          bidHistory = bidHistory;
          remainingTime = auction.remainingTime;
          isActive = auction.isActive;
          winningBid = auction.winningBid;
          reservePrice = auction.reservePrice;
          owner = auction.owner;
          minBidIncrement = auction.minBidIncrement;
        });
      };
    };
  };

  // Get active auctions with optional category filter
  public query func getActiveAuctions(category : ?Text) : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(auctions, func(auction) {
      let categoryMatch = switch (category) {
        case null { true };
        case (?cat) { auction.item.title == cat };
      };
      auction.isActive and auction.remainingTime > 0 and categoryMatch
    });

    List.toArray(List.map<Auction, AuctionDetails>(activeAuctions, func (auction) {
      let bidHistory = List.toArray(List.reverse(auction.bidHistory));
      {
        item = auction.item;
        bidHistory = bidHistory;
        remainingTime = auction.remainingTime;
        isActive = auction.isActive;
        winningBid = auction.winningBid;
        reservePrice = auction.reservePrice;
        owner = auction.owner;
        minBidIncrement = auction.minBidIncrement;
      }
    }))
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

  // Timer to update auction times regularly
  private let auctionTimer = Timer.recurringTimer(
    #seconds(60),
    func() : async () {
      await updateAuctionTimes();
    }
  );
}
