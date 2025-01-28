import List "mo:base/List";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Timer "mo:base/Timer";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import { auctionToAuctionDetails } "Utils";
import T "Types";

actor {
  type List<T> = List.List<T>;
  type Order = Order.Order;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  stable var auctions = List.nil<T.Auction>();
  stable var idCounter : Nat = 0;

  /// Get the auction details for an auction with a given id
  public query func getAuctionDetails(
    auctionId : T.AuctionId
  ) : async Result<T.AuctionDetails, T.AuctionError> {
    switch (findAuction(auctionId)) {
      case (#ok(auction)) #ok(auctionToAuctionDetails(auction));
      case (#err(err)) #err(err);
    };
  };

  /// Retrieve a list of all active auctions
  public query func listActiveAuctions() : async List<T.AuctionDetails> {
    List.mapFilter<T.Auction, T.AuctionDetails>(
      auctions,
      func auction {
        if (auction.remainingTime > 0) {
          ?auctionToAuctionDetails(auction);
        } else {
          null;
        };
      },
    );
  };

  /// Allows users to retrieve their bidding history across all auctions
  public query ({ caller }) func myBiddingHistory() : async List<T.Bid> {
    List.flatten<T.Bid>(
      List.map<T.Auction, List<T.Bid>>(
        auctions,
        func auction {
          List.filter<T.Bid>(
            auction.bidHistory,
            func bid = bid.originator == caller,
          );
        },
      )
    );
  };

  /// Place a bid in an auction
  public shared ({ caller }) func makeBid(
    auctionId : T.AuctionId,
    price : Nat,
  ) : async Result<(), T.AuctionError> {
    switch (findAuction(auctionId)) {
      case (#ok(auction)) {
        // can't bid on a closed auction
        if (auction.remainingTime == 0) return #err(#AuctionClosed);

        // must place a higher bid than the current highest bid
        switch (highestBid(auction)) {
          case (?bid) if (bid.price >= price) return #err(#BidTooLow({ highestBid = bid.price }));
          case (null) {};
        };

        let bid = {
          price;
          time = Int.abs(Time.now());
          originator = caller;
        };
        auction.bidHistory := List.push(bid, auction.bidHistory);
        #ok;
      };
      case (#err(err)) #err(err);
    };
  };

  /// Create a new auction
  public shared ({ caller }) func newAuction(item : T.Item, durationInSeconds : Nat) : async () {
    let auction = {
      id = generateAuctionId();
      item;
      var bidHistory = List.nil();
      var remainingTime = durationInSeconds;
      var closingTime = Time.now() + durationInSeconds * 1_000_000_000;
      var reservePrice = null;
      var winningBid = null;
      owner = caller;
    } : T.Auction;

    auctions := List.push(auction, auctions);

    // set timer for closing the auction once remainingTime is over
    ignore Timer.setTimer<system>(
      #seconds durationInSeconds,
      func() : async () { closeAuction(auction) },
    );
  };

  /// Allows the auction owner i.e creator to set a reserve price
  public shared ({ caller }) func setReservePrice(
    auctionId : T.AuctionId,
    reservePrice : Nat,
  ) : async Result<(), T.AuctionError> {
    switch (findAuction(auctionId)) {
      case (#ok(auction)) {
        if (auction.owner == caller) {
          auction.reservePrice := ?reservePrice;
        } else {
          return #err(#CallerNotTheOwner);
        };
        #ok;
      };
      case (#err(err)) #err(err);
    };
  };

  /// Find an auction with a given id
  func findAuction(auctionId : T.AuctionId) : Result<T.Auction, T.AuctionError> {
    switch (List.find<T.Auction>(auctions, func auction = auction.id == auctionId)) {
      case (?auction) #ok(auction);
      case (null) #err(#NoAuctionWithId auctionId);
    };
  };

  /// Generate a unique id for an auction
  func generateAuctionId() : Nat {
    idCounter += 1;
    idCounter;
  };

  /// Close an auction
  func closeAuction(auction : T.Auction) {
    auction.remainingTime := 0; // closed
    // Determine winning bid
    auction.winningBid := switch (highestBid(auction)) {
      case (?bid) {
        switch (auction.reservePrice) {
          case (?reservePrice) if (bid.price >= reservePrice) ?bid else null;
          case (null) ?bid;
        };
      };
      case (null) null; // no winning bid
    };
  };

  /// Get the highest placed bid
  func highestBid(auction : T.Auction) : ?T.Bid {
    switch (auction.bidHistory) {
      case (?(head, _)) ?head;
      case null null;
    };
  };

  /// Distilling necessary timer information from stable auctions
  func rescheduleTimersForClosingAuctions<system>() {
    // get active auctions
    let activeAuctions = List.filter<T.Auction>(auctions, func a = a.remainingTime > 0);
    for (auction in Iter.fromList(activeAuctions)) {
      let now = Time.now();
      if (auction.closingTime < now) {
        // close the auction since closing time has already expired
        closeAuction(auction);
      } else {
        // closing time not expired, thus schedule closure of auction
        let durationInNanoseconds = Int.abs(auction.closingTime - now);
        ignore Timer.setTimer<system>(
          #nanoseconds durationInNanoseconds,
          func() : async () { closeAuction(auction) },
        );
      };
    };
  };

  system func postupgrade() {
    /// Timers are not persisted across upgrades, thus recreating them
    rescheduleTimersForClosingAuctions<system>();
  };

};
