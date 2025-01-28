import List "mo:base/List";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Int "mo:base/Int";

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
    var status : AuctionStatus;
    var winner : ?Principal;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
  };

  type AuctionStatus = {
    #active;
    #closed;
  };

  system func heartbeat() : async () {
    await updateAuctions();
  };

  let TIMER_INTERVAL = 1_000_000_000;

  private var timerId : Timer.TimerId = 0;

  public func init() : async () {
    timerId := Timer.setTimer<system>(#seconds 1, updateAuctions);
  };

  private func updateAuctions() : async () {
    var updatedAuctions = List.nil<Auction>();

    for (auction in List.toArray(auctions).vals()) {
      if (auction.remainingTime > 0) {
        auction.remainingTime := auction.remainingTime - 1;

        if (auction.remainingTime == 0) {
          await closeAuction(auction);
        };
      };
      updatedAuctions := List.push(auction, updatedAuctions);
    };

    auctions := updatedAuctions;

    timerId := Timer.setTimer<system>(#seconds 1, updateAuctions);
  };

  private func closeAuction(auction : Auction) : async () {
    auction.status := #closed;

    let bids = List.toArray(auction.bidHistory);
    if (bids.size() > 0) {
      var highestBid = bids[0];
      for (bid in bids.vals()) {
        if (bid.price > highestBid.price) {
          highestBid := bid;
        };
      };
      auction.winner := ?highestBid.originator;
    };
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

  public func newAuction(item : Item, duration : Nat) : async Result.Result<(), Text> {
    // Implementation here
    if (item.title == "") {
      return #err("Title cannot be empty");
    };

    if (item.description == "") {
      return #err("Description cannot be empty");
    };

    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      var status = #active;
      var winner = null;
    };

    auctions := List.push(newAuction, auctions);
    idCounter += 1;

    #ok(());
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    {
      item = auction.item;
      bidHistory;
      remainingTime = auction.remainingTime;
      status = auction.status;
      winner = auction.winner;
    };
  };

  public query func getAllAuctions() : async [AuctionDetails] {
    let auctionList = List.toArray(auctions);

    Array.map<Auction, AuctionDetails>(auctionList, func(auction) { { item = auction.item; bidHistory = List.toArray(List.reverse(auction.bidHistory)); remainingTime = auction.remainingTime } });
  };

  public query func getActiveAuctions() : async [AuctionDetails] {
    let auctionsList = List.toArray(auctions);
    Array.map<Auction, AuctionDetails>(
      Array.filter<Auction>(auctionsList, func(auction) { auction.remainingTime > 0 }),
      func(auction) {
        {
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
        };
      },
    );
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
    // Implementation here
    let auction = findAuction(auctionId);

    if (auction.status != #active) {
      return #err("Auction is not active");
    };

    if (auction.remainingTime == 0) {
      return #err("Auction has ended");
    };

    let currentBids = List.toArray(auction.bidHistory);
    if (currentBids.size() > 0) {
      let highestBid = Array.foldLeft<Bid, Nat>(
        currentBids,
        0,
        func(maxPrice, bid) {
          if (bid.price > maxPrice) { bid.price } else { maxPrice };
        },
      );
      if (price <= highestBid) {
        return #err("Bid must be higher thancurrent highest bid");
      };
    };

    let newBid : Bid = {
      price;
      time = Int.abs(Time.now());
      originator = message.caller;
    };

    auction.bidHistory := List.push(newBid, auction.bidHistory);
    #ok(());
  };
};
