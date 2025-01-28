import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Hash "mo:base/Hash";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";

actor class AuctionSystem() {

  // Types

  type Result<Ok, Err> = Result.Result<Ok, Err>;

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

  type AuctionStatus = {
    #Active;
    #Closed;
    #Reserved;
    #Cancelled;
  };

  type AuctionError = {
    #AuctionNotFound;
    #InsufficientBid;
    #AuctionClosed;
    #UnauthorizedAccess;
    #InvalidInput;
    #SystemError;
  };

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    creator : Principal;
    reservePrice : Nat;
    var status : AuctionStatus;
    createdAt : Int;
    var lastUpdated : Int;
  };

  type AuctionDetails = {
    id : AuctionId;
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    status : AuctionStatus;
    reservePrice : Nat;
    creator : Principal;
    createdAt : Int;
    lastUpdated : Int;
  };

  // Stable Storage

  private stable var upgradeCounter : Nat = 0;
  private stable var lastUpgradeTime : Int = 0;
  private stable var auctions = List.nil<Auction>();
  private stable var idCounter : Nat = 0;
  private stable var userBidHistory = List.nil<(Principal, List.List<(AuctionId, Bid)>)>();

  // Upgrade Hooks

  system func preupgrade() {
    Debug.print("Preparing for upgrade...");
    Debug.print("Current number of auctions: " # debug_show(List.size(auctions)));
    Debug.print("Current number of bid histories: " # debug_show(List.size(userBidHistory)));
  };

  system func postupgrade() {
    Debug.print("Upgrade completed successfully");
    upgradeCounter += 1;
    lastUpgradeTime := Time.now();
    validateDataIntegrity();
  };

  private func validateDataIntegrity() {
    // Verify auctions data
    for (auction in List.toArray(auctions).vals()) {
      assert(auction.id > 0 and auction.id <= idCounter);
      assert(auction.remainingTime >= 0);
      assert(auction.reservePrice >= 0);
    };

    // Verify bid history consistency
    for ((principal, bids) in List.toArray(userBidHistory).vals()) {
      assert(Principal.toText(principal).size() > 0);
      for ((auctionId, bid) in List.toArray(bids).vals()) {
        assert(bid.price > 0);
        assert(bid.time <= Time.now());
      };
    };

    Debug.print("Data integrity validation completed");
  };

  public query func getUpgradeStatus() : async {
    upgradeCounter : Nat;
    lastUpgradeTime : Int;
  } {
    {
      upgradeCounter;
      lastUpgradeTime;
    }
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async Result<AuctionDetails, AuctionError> {
    switch (findAuction(auctionId)) {
      case (#ok(auction)) {
        #ok({
          id = auction.id;
          item = auction.item;
          bidHistory = List.toArray(List.reverse(auction.bidHistory));
          remainingTime = auction.remainingTime;
          status = auction.status;
          reservePrice = auction.reservePrice;
          creator = auction.creator;
          createdAt = auction.createdAt;
          lastUpdated = auction.lastUpdated;
        })
      };
      case (#err(error)) #err(error);
    }
  };

  public query func getActiveAuctions() : async [AuctionDetails] {
    List.toArray(
      List.map<Auction, AuctionDetails>(
        List.filter<Auction>(auctions, isAuctionActive),
        auctionToDetails
      )
    )
  };

  public query func getUserBidHistory(user : Principal) : async [(AuctionId, Bid)] {
    switch (findUserBidHistory(user)) {
      case null [];
      case (?history) List.toArray(history);
    }
  };

  public shared(msg) func newAuction(
    item : Item, 
    duration : Nat, 
    reservePrice : Nat
  ) : async Result<AuctionId, AuctionError> {
    if (duration == 0 or reservePrice == 0) {
      return #err(#InvalidInput);
    };

    idCounter += 1;
    
    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      creator = msg.caller;
      reservePrice = reservePrice;
      var status = #Active;
      createdAt = Time.now();
      var lastUpdated = Time.now();
    };

    auctions := List.push(newAuction, auctions);
    #ok(idCounter)
  };

  public shared(msg) func makeBid(
    auctionId : AuctionId, 
    price : Nat
  ) : async Result<(), AuctionError> {
    switch (findAuction(auctionId)) {
      case (#err(error)) return #err(error);
      case (#ok(auction)) {
        if (not isAuctionActive(auction)) {
          return #err(#AuctionClosed);
        };

        if (not validateBid(auction, price)) {
          return #err(#InsufficientBid);
        };

        let newBid : Bid = {
          price = price;
          time = Time.now();
          originator = msg.caller;
        };

        auction.bidHistory := List.push(newBid, auction.bidHistory);
        auction.lastUpdated := Time.now();
        
        await updateUserBidHistory(msg.caller, auctionId, newBid);
        #ok(())
      };
    }
  };

  private func findAuction(auctionId : AuctionId) : Result<Auction, AuctionError> {
    switch (List.find<Auction>(auctions, func(a) = a.id == auctionId)) {
      case null #err(#AuctionNotFound);
      case (?auction) #ok(auction);
    }
  };

  private func isAuctionActive(auction : Auction) : Bool {
    auction.remainingTime > 0 and auction.status == #Active
  };

  private func validateBid(auction : Auction, price : Nat) : Bool {
    switch (List.get(auction.bidHistory, 0)) {
      case (?currentBid) price > currentBid.price;
      case null price >= auction.reservePrice;
    }
  };

  private func findUserBidHistory(user : Principal) : ?List.List<(AuctionId, Bid)> {
    Option.map<(Principal, List.List<(AuctionId, Bid)>), List.List<(AuctionId, Bid)>>(
      List.find<(Principal, List.List<(AuctionId, Bid)>)>(
        userBidHistory,
        func((p, _)) = Principal.equal(p, user)
      ),
      func((_, history)) = history
    )
  };

  private func auctionToDetails(auction : Auction) : AuctionDetails {
    {
      id = auction.id;
      item = auction.item;
      bidHistory = List.toArray(List.reverse(auction.bidHistory));
      remainingTime = auction.remainingTime;
      status = auction.status;
      reservePrice = auction.reservePrice;
      creator = auction.creator;
      createdAt = auction.createdAt;
      lastUpdated = auction.lastUpdated;
    }
  };

  private func updateUserBidHistory(
    user : Principal,
    auctionId : AuctionId,
    bid : Bid
  ) : async () {
    let newBidEntry = (auctionId, bid);
    
    switch (findUserBidHistory(user)) {
      case null {
        userBidHistory := List.push(
          (user, List.push(newBidEntry, List.nil())),
          userBidHistory
        );
      };
      case (?history) {
        userBidHistory := List.map<(Principal, List.List<(AuctionId, Bid)>), (Principal, List.List<(AuctionId, Bid)>)>(
          userBidHistory,
          func((p, h)) {
            if (Principal.equal(p, user)) {
              (p, List.push(newBidEntry, h))
            } else {
              (p, h)
            }
          }
        );
      };
    };
  };

  system func timer(setTimer : Nat64 -> ()) : async () {
      await processAuctions();
  };

  private func processAuctions() : async () {
    auctions := List.map<Auction, Auction>(
      auctions,
      func(auction) {
        if (isAuctionActive(auction)) {
          if (auction.remainingTime > 0) {
            auction.remainingTime -= 1;
          };

          if (auction.remainingTime == 0) {
            closeAuction(auction);
          };
        };
        auction
      }
    );
  };

  private func closeAuction(auction : Auction) {
    switch (List.get(auction.bidHistory, 0)) {
      case (?highestBid) {
        if (highestBid.price >= auction.reservePrice) {
          auction.status := #Closed;
        } else {
          auction.status := #Reserved;
        };
      };
      case null {
        auction.status := #Reserved;
      };
    };
    auction.lastUpdated := Time.now();
  };

  public query func _getSystemState() : async {
    auctionCount : Nat;
    activeAuctions : Nat;
    totalBids : Nat;
    upgradeCount : Nat;
  } {
    let activeCount = List.size(List.filter<Auction>(auctions, isAuctionActive));
    let totalBids = List.foldLeft<Auction, Nat>(
      auctions,
      0,
      func(acc, auction) = acc + List.size(auction.bidHistory)
    );

    {
      auctionCount = List.size(auctions);
      activeAuctions = activeCount;
      totalBids = totalBids;
      upgradeCount = upgradeCounter;
    }
  };

}