import List "mo:base/List";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";

actor AuctionDApp {
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
    var remainingTime : Int;
    startTime : Int;
    reservePrice : Nat;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Int;
    reservePrice : Nat;
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter : Nat = 0;

  func findAuction(auctionId : AuctionId) : ?Auction {
    List.find<Auction>(auctions, func (auction) { auction.id == auctionId })
  };

  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
    let id = idCounter;
    idCounter += 1;

    let newAuction : Auction = {
      id = id;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = Int.abs(duration);
      startTime = Time.now();
      reservePrice = reservePrice;
    };

    auctions := List.push(newAuction, auctions);
    id
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Text> {
    switch (findAuction(auctionId)) {
      case null { #err("Auction not found") };
      case (?auction) {
        let currentTime = Time.now();
        let elapsedTime = (currentTime - auction.startTime) / 1_000_000_000; // Convert nanoseconds to seconds
        let remainingTime = Int.max(0, auction.remainingTime - elapsedTime);
        
        #ok({
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = remainingTime;
          reservePrice = auction.reservePrice;
        })
      };
    }
  };

  public query func getActiveAuctions() : async [AuctionDetails] {
    let currentTime = Time.now();
    List.toArray(
      List.mapFilter<Auction, AuctionDetails>(auctions,
        func (auction) {
          let elapsedTime = (currentTime - auction.startTime) / 1_000_000_000; // Convert nanoseconds to seconds
          let remainingTime = Int.max(0, auction.remainingTime - elapsedTime);

          if (remainingTime > 0) {
            ?{
              item = auction.item;
              bidHistory = List.toArray(List.reverse(auction.bidHistory));
              remainingTime = remainingTime;
              reservePrice = auction.reservePrice;
            }
          } else {
            null
          }
        }
      )
    )
  };

  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Text> {
    switch (findAuction(auctionId)) {
      case null { #err("Auction not found") };
      case (?auction) {
        let currentTime = Time.now();
        let elapsedTime = (currentTime - auction.startTime) / 1_000_000_000; // Convert nanoseconds to seconds
        
        if (elapsedTime >= auction.remainingTime) {
          return #err("Auction has ended");
        };

        switch (List.get(auction.bidHistory, 0)) {
          case null {
            // First bid
            if (price < auction.reservePrice) {
              return #err("Bid must be at least the reserve price");
            };
            let newBid : Bid = {
              price = price;
              time = currentTime;
              originator = message.caller;
            };
            auction.bidHistory := List.push(newBid, auction.bidHistory);
            #ok()
          };
          case (?highestBid) {
            if (price <= highestBid.price) {
              return #err("Bid must be higher than the current highest bid")
            } else {
              let newBid : Bid = {
                price = price;
                time = currentTime;
                originator = message.caller;
              };
              auction.bidHistory := List.push(newBid, auction.bidHistory);
              #ok()
            }
          };
        }
      };
    }
  };

  public query func getUserBidHistory(user : Principal) : async [(AuctionId, [Bid])] {
    List.toArray(
      List.mapFilter<Auction, (AuctionId, [Bid])>(auctions,
        func (auction) {
          let userBids = List.filter<Bid>(auction.bidHistory, func (bid) { bid.originator == user });
          if (List.size(userBids) > 0) {
            ?(auction.id, List.toArray(userBids))
          } else {
            null
          }
        }
      )
    )
  };

  // Helper function to update remaining time and close auctions
  private func updateAuctions() : async () {
    let currentTime = Time.now();
    auctions := List.map<Auction, Auction>(auctions,
      func (auction) {
        let elapsedTime = (currentTime - auction.startTime) / 1_000_000_000; // Convert nanoseconds to seconds
        let remainingTime = Int.max(0, auction.remainingTime - elapsedTime);
        
        if (remainingTime == 0) {
          // Auction has ended
          switch (List.get(auction.bidHistory, 0)) {
            case null { Debug.print("Auction " # debug_show(auction.id) # " ended with no bids") };
            case (?winningBid) {
              if (winningBid.price >= auction.reservePrice) {
                Debug.print("Auction " # debug_show(auction.id) # " ended. Winner: " # debug_show(winningBid.originator) # " with bid: " # debug_show(winningBid.price));
              } else {
                Debug.print("Auction " # debug_show(auction.id) # " ended without meeting reserve price");
              };
            };
          };
        };

        {
          id = auction.id;
          item = auction.item;
          var bidHistory = auction.bidHistory;
          var remainingTime = remainingTime;
          startTime = auction.startTime;
          reservePrice = auction.reservePrice;
        }
      }
    );
  };

  // System function to periodically update auctions
  system func heartbeat() : async () {
    await updateAuctions();
  };

  // Total Auctions function
  public query func getTotalAuctions() : async Nat {
    List.size(auctions)
  };

  // Highest Bid function
  public query func getHighestBid(auctionId : AuctionId) : async Result.Result<Nat, Text> {
    switch (findAuction(auctionId)) {
      case null { 
        #err("Auction not found") 
      };
      case (?auction) {
        switch (List.get(auction.bidHistory, 0)) {
          case null {
            #err("No bids placed")
          };
          case (?highestBid) {
            #ok(highestBid.price)
          }
        };
      };
    }
  };
} 