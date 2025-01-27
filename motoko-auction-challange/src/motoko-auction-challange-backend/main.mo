import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
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
    reservePrice : Nat;
    var isActive : Bool;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    isActive : Bool;
  };

  stable var auctions : List.List<Auction> = List.nil<Auction>();
  stable var idCounter : Nat = 0;

  func findAuction(auctionId : AuctionId) : ?Auction {
    List.find<Auction>(auctions, func (auction : Auction) : Bool {
      auction.id == auctionId
    })
  };

  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async () {
    let auction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      reservePrice = reservePrice;
      var isActive = true;
    };
    idCounter += 1;
    auctions := List.push(auction, auctions);
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Text> {
    switch (findAuction(auctionId)) {
      case null #err("Auction with given ID not found.");
      case (?auction) {
        let bidHistory : [Bid] = List.toArray(List.reverse(auction.bidHistory));
        #ok({
          item = auction.item;
          bidHistory = bidHistory;
          remainingTime = auction.remainingTime;
          isActive = auction.isActive;
        })
      };
    }
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
    switch (findAuction(auctionId)) {
      case null #err("Auction with given ID not found.");
      case (?auction) {
        if (not auction.isActive or auction.remainingTime == 0) {
          return #err("Auction is not active.");
        };
        let highestBid : Nat = switch (List.get(auction.bidHistory, 0)) {
          case null 0;
          case (?bid) bid.price;
        };
        if (price <= highestBid) {
          return #err("Bid price must be higher than the current highest bid.");
        };
        let newBid : Bid = {
          price = price;
          time = Time.now();
          originator = message.caller;
        };
        auction.bidHistory := List.push(newBid, auction.bidHistory);
        #ok(())
      };
    }
  };

  public query func getActiveAuctions() : async [AuctionDetails] {
    List.toArray(List.map<Auction, AuctionDetails>(
      List.filter<Auction>(auctions, func (auction : Auction) : Bool {
        auction.remainingTime > 0 and auction.isActive
      }),
      func (auction : Auction) : AuctionDetails {
        {
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
          isActive = auction.isActive;
        }
      }
    ));
  };

  func closeAuction(auction : Auction) {
    auction.isActive := false;
    let highestBid : ?Bid = List.get(auction.bidHistory, 0);
    switch (highestBid) {
      case null Debug.print("Reserve price not met. Item not sold.");
      case (?bid) {
        if (bid.price < auction.reservePrice) {
          Debug.print("Reserve price not met. Item not sold.");
        } else {
          Debug.print("Auction closed. Winner: " # Principal.toText(bid.originator) # ", Price: " # Nat.toText(bid.price));
        };
      };
    };
  };

  public func checkAndCloseAuctions() : async () {
    auctions := List.map<Auction, Auction>(auctions, func (auction : Auction) : Auction {
      if (auction.isActive and auction.remainingTime == 0) {
        closeAuction(auction);
      };
      auction
    });
  };

  public func getUserBidHistory(user : Principal) : async [Bid] {
    List.toArray(List.flatten<Bid>(
      List.map<Auction, List.List<Bid>>(auctions, func (auction : Auction) : List.List<Bid> {
        List.filter<Bid>(auction.bidHistory, func (bid : Bid) : Bool { 
          bid.originator == user 
        })
      })
    ));
  };

  system func heartbeat() : async () {
    auctions := List.map<Auction, Auction>(auctions, func (auction : Auction) : Auction {
      if (auction.isActive and auction.remainingTime > 0) {
        auction.remainingTime -= 1;
      };
      auction
    });
    await checkAndCloseAuctions();
  };
}