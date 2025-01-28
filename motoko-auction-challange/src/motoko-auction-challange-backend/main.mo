import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Nat "mo:base/Nat";

actor AuctionSystem {
  type Item = {
    title : Text;
    description : Text;
    image : Blob;
  };

  type Bid = {
    price : Nat;
    time : Int; // Use Int for time
    originator : Principal;
  };

  type AuctionId = Nat;
  type AuctionStatus = { #Active; #Closed };

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    var reservePrice : Nat;
    var status : AuctionStatus;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    status : AuctionStatus;
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;

  // Helper function to find an auction by ID
  func findAuction(auctionId : AuctionId) : Result.Result<Auction, Text> {
    let result = List.find<Auction>(auctions, func(auction) { auction.id == auctionId });
    switch (result) {
      case null #err("Invalid auction ID");
      case (?auction) #ok(auction);
    };
  };

  // Create a new auction
  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
    idCounter += 1;
    let newAuction : Auction = {
      id = idCounter;
      item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      var reservePrice = reservePrice;
      var status = #Active;
    };
    auctions := List.push(newAuction, auctions);
    Debug.print("New auction created with ID: " # debug_show(idCounter));
    idCounter;
  };

  // Retrieve auction details
  public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Text> {
    switch (findAuction(auctionId)) {
      case (#err(msg)) #err(msg);
      case (#ok(auction)) {
        #ok({
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
          status = auction.status;
        });
      };
    };
  };

  // Place a bid on an auction
  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
    switch (findAuction(auctionId)) {
      case (#err(msg)) #err(msg);
      case (#ok(auction)) {
        if (auction.status == #Closed or auction.remainingTime == 0) {
          #err("Auction is closed");
        } else if (price < auction.reservePrice) {
          #err("Bid must be at least the reserve price: " # debug_show(auction.reservePrice));
        } else {
          let currentHighestBid = List.foldLeft<Bid, Nat>(
            auction.bidHistory,
            0,
            func(acc, bid) { if (bid.price > acc) bid.price else acc }
          );
          
          if (price <= currentHighestBid) {
            #err("Bid must be higher than current highest bid: " # debug_show(currentHighestBid));
          } else {
            let newBid : Bid = {
              price;
              time = Time.now();
              originator = message.caller;
            };
            auction.bidHistory := List.push(newBid, auction.bidHistory);
            Debug.print("Bid recorded for auction ID " # debug_show(auctionId) # ": " # debug_show(newBid));
            #ok(());
          };
        };
      };
    };
  };

  // Periodic timer to close expired auctions
  system func heartbeat() : async () {
    auctions := List.map<Auction, Auction>(auctions, func(auction) {
      if (auction.status == #Active and auction.remainingTime > 0) {
        auction.remainingTime -= 1;
        if (auction.remainingTime == 0) {
          closeAuction(auction);
        };
      };
      auction;
    });
  };

  // Close an auction and determine the winner
  func closeAuction(auction : Auction) : () {
    auction.status := #Closed;
    let winningBid = List.foldLeft<Bid, ?Bid>(auction.bidHistory, null, func(acc, bid) {
      switch (acc) {
        case null { ?bid };
        case (?prevBid) { if (bid.price > prevBid.price) ?bid else acc };
      };
    });
    switch (winningBid) {
      case null { Debug.print("No bids placed for auction ID: " # debug_show(auction.id)); };
      case (?bid) {
        if (bid.price >= auction.reservePrice) {
          Debug.print("Auction ID " # debug_show(auction.id) # " won by: " # Principal.toText(bid.originator));
        } else {
          Debug.print("Reserve price not met for auction ID: " # debug_show(auction.id));
        };
      };
    };
  };

  // Retrieve bidding history for a user
  public query func getBiddingHistory(user : Principal) : async [Bid] {
    let allBids = List.flatten(List.map<Auction, List.List<Bid>>(auctions, func(auction) { auction.bidHistory }));
    let filteredBids = Array.filter<Bid>(List.toArray(allBids), func(bid) { bid.originator == user });
    Debug.print("Bidding history for user " # Principal.toText(user) # ": " # debug_show(filteredBids));
    filteredBids;
  };

  // Retrieve all active auctions
  public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(auctions, func(auction) { auction.status == #Active and auction.remainingTime > 0 });
    List.toArray(List.map<Auction, AuctionDetails>(activeAuctions, func(auction) {
      {
        item = auction.item;
        bidHistory = List.toArray(List.reverse(auction.bidHistory));
        remainingTime = auction.remainingTime;
        status = auction.status;
      }
    }));
  };
};