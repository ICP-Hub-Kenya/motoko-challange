import Types "types";
import Utils "utils";
import List "mo:base/List";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import { recurringTimer } = "mo:base/Timer";

actor {
  type Auction = Types.Auction;
  type AuctionId = Types.AuctionId;
  type Item = Types.Item;
  type Bid = Types.Bid;
  type AuctionStatus = Types.AuctionStatus;
  type AuctionDetails = Types.AuctionDetails;
  type ApiError = Types.ApiError;
  type Result<A, B> = Types.Result<A, B>;

  // Reads and Writes are O(1)
  stable let auctions = Map.new<AuctionId, Auction>();

  func findAuction(auctionId : AuctionId) : ?Auction {
    Map.get(auctions, thash, auctionId);
  };

  // Create a new auction
  // Duration is in seconds
  public func newAuction(item : Item, duration : Nat) : async Result<AuctionId, ApiError> {
    let id = await Utils.uuid();
    let auction = {
      id = id;
      item = item;
      endTime = Utils.intToNat(Time.now()) + (duration * 1_000_000_000);
      bidHistory = List.nil();
      status = #Active;
    };
    Map.set(auctions, thash, id, auction);
    #ok(id);
  };

  // Get auction details
  public query func getAuctionDetails(auctionId : AuctionId) : async Result<AuctionDetails, ApiError> {
    let auction = findAuction(auctionId);
    switch (auction) {
      case (null) {
        #err(#NotFound);
      };
      case (?a) {
        let bidHistory = List.toArray(List.reverse(a.bidHistory));
        #ok({
          item = a.item;
          bidHistory;
          remainingTime = Utils.getRemTime(a.endTime);
          status = a.status;
        });
      };
    };
  };

  // Get all active auctions
  public query func getActiveAuctions() : async Result<[AuctionDetails], ()> {
    // Get all auctions as an iterator
    let allAuctions = Map.vals(auctions);

    // Filter active auctions
    let activeAuctions = Iter.filter(allAuctions, func(x : Auction) : Bool { x.status == #Active });

    // Map to AuctionDetails
    var auctionDetails = Iter.map(
      activeAuctions,
      func(x : Auction) : AuctionDetails {
        let bidHistory = List.toArray(List.reverse(x.bidHistory));
        {
          item = x.item;
          bidHistory;
          remainingTime = Utils.getRemTime(x.endTime);
          status = x.status;
        };
      },
    );

    // Filter auctions that still have time left
    auctionDetails := Iter.filter(
      auctionDetails,
      func(x : AuctionDetails) : Bool { x.remainingTime > 0 },
    );
    #ok(Iter.toArray(auctionDetails));
  };

  // Get a user bidding history
  public shared ({ caller }) func getUserBiddingHistory() : async Result<[Bid], ApiError> {
    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized);
    };

    let allAuctions = Map.vals(auctions);
    let userBids = Iter.map(
      allAuctions,
      func(x : Auction) : List.List<Bid> {
        List.filter(x.bidHistory, func(bid : Bid) : Bool { bid.originator == caller });
      },
    );

    let allBids = Iter.toList(userBids);
    #ok(List.toArray(List.flatten(allBids)));
  };

  // Make a bid
  public shared ({ caller }) func makeBid(auctionId : AuctionId, price : Nat) : async Result<(), ApiError> {
    if (Principal.isAnonymous(caller)) {
      return #err(#NotAuthorized);
    };

    switch (findAuction(auctionId)) {
      case (null) { #err(#NotFound) };
      case (?auction) {
        if (auction.status != #Active) {
          return #err(#AuctionEnded);
        };

        let newBid : Bid = {
          originator = caller;
          price = price;
          time = Time.now();
        };
        let bids = List.push<Bid>(newBid, auction.bidHistory);

        // Update the auction
        let updatedAuction = {
          id = auction.id;
          item = auction.item;
          endTime = auction.endTime;
          bidHistory = bids;
          status = auction.status;
        };
        Map.set(auctions, thash, auction.id, updatedAuction);
        #ok();
      };
    };
  };

  private func checkEndedAuctions() : async () {
    let currentTime = Time.now();
    let auctionsArray = Map.vals(auctions);

    for (auction in auctionsArray) {
      if (auction.status == #Active and auction.endTime <= currentTime) {

        // Find the highest bid
        let highestBid = List.foldLeft<Bid, Bid>(
          auction.bidHistory,
          { price = 0; time = 0; originator = Principal.fromText("") },
          func(bid : Bid, acc : Bid) : Bid {
            if (bid.price > acc.price) {
              bid;
            } else {
              acc;
            };
          },
        );

        // Check if the reserve price was met
        // By default the highest bid must be greater than 0
        var meetsReserve = highestBid.price > 0;
        switch (auction.item.reservePrice) {
          case (null) {};
          case (?reservePrice) {
            meetsReserve := meetsReserve and (highestBid.price >= reservePrice);
          };
        };

        let newStatus = if (meetsReserve) { #Ended } else {
          #ReservePriceNotMet;
        };

        // Update the auction status
        let updatedAuction = {
          id = auction.id;
          item = auction.item;
          endTime = auction.endTime;
          bidHistory = auction.bidHistory;
          status = newStatus;
        };
        Map.set(auctions, thash, auction.id, updatedAuction);
      };
    };
  };

  // Set a recurring timer to check for ended auctions every second
  ignore recurringTimer<system>(#seconds 1, checkEndedAuctions);
};
