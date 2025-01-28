import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
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
    category: Category;
    condition: Text;
    tags: [Text];
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
    var watchlist: List.List<Principal>;
    buyNowPrice: ?Nat;
    var automaticExtension: Bool;
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

    type Category = {
    #Art;
    #Electronics;
    #Collectibles;
    #RealEstate;
    #Vehicles;
    #Other;
  };

  type AutoBidConfig = {
    maxAmount: Nat;
    incrementAmount: Nat;
    targetAuctionId: AuctionId;
  };

  // Stable Storage

  private stable var upgradeCounter : Nat = 0;
  private stable var lastUpgradeTime : Int = 0;
  private stable var auctions = List.nil<Auction>();
  private stable var idCounter : Nat = 0;
  private stable var userBidHistory = List.nil<(Principal, List.List<(AuctionId, Bid)>)>();
  private stable var userAutoBids = List.nil<(Principal, List.List<AutoBidConfig>)>();
  private stable var userWatchlist = List.nil<(Principal, List.List<AuctionId>)>();
  private stable var categories = List.nil<(Category, Nat)>();

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
    item: Item,
    duration: Nat,
    reservePrice: Nat,
    buyNowPrice: ?Nat,
    automaticExtension: Bool
  ) : async Result<AuctionId, AuctionError> {
    if (duration == 0 or reservePrice == 0) {
      return #err(#InvalidInput);
    };

    switch(buyNowPrice) {
      case (?price) {
        if (price <= reservePrice) {
          return #err(#InvalidInput);
        };
      };
      case null {};
    };

    idCounter += 1;
    
    let newAuction: Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
      creator = msg.caller;
      reservePrice = reservePrice;
      var status = #Active;
      createdAt = Time.now();
      var lastUpdated = Time.now();
      var watchlist = List.nil<Principal>();
      buyNowPrice = buyNowPrice;
      var automaticExtension = automaticExtension;
    };

    auctions := List.push(newAuction, auctions);
    await updateCategoryStats(item.category);
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

  system func timer(_setTimer : Nat64 -> ()) : async () {
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

  public shared(msg) func addToWatchlist(auctionId: AuctionId) : async Result<(), AuctionError> {
    switch (findAuction(auctionId)) {
      case (#err(error)) return #err(error);
      case (#ok(auction)) {
        if (not List.some(auction.watchlist, func(p: Principal): Bool = Principal.equal(p, msg.caller))) {
            auction.watchlist := List.push(msg.caller, auction.watchlist);
        };
        await updateUserWatchlist(msg.caller, auctionId);
        #ok(())
      };
    }
  };

  public shared(msg) func setAutoBid(config: AutoBidConfig) : async Result<(), AuctionError> {
    switch (findAuction(config.targetAuctionId)) {
      case (#err(error)) return #err(error);
      case (#ok(auction)) {
        if (not isAuctionActive(auction)) {
          return #err(#AuctionClosed);
        };
        
        await updateUserAutoBids(msg.caller, config);
        await processAutoBid(msg.caller, config);
        #ok(())
      };
    }
  };

  public shared(msg) func buyNow(auctionId: AuctionId) : async Result<(), AuctionError> {
    switch (findAuction(auctionId)) {
      case (#err(error)) return #err(error);
      case (#ok(auction)) {
        switch (auction.buyNowPrice) {
          case null return #err(#InvalidInput);
          case (?price) {
            if (not isAuctionActive(auction)) {
              return #err(#AuctionClosed);
            };

            let buyNowBid: Bid = {
              price = price;
              time = Time.now();
              originator = msg.caller;
            };

            auction.bidHistory := List.push(buyNowBid, auction.bidHistory);
            auction.status := #Closed;
            auction.lastUpdated := Time.now();
            
            await updateUserBidHistory(msg.caller, auctionId, buyNowBid);
            #ok(())
          };
        }
      };
    }
  };

  private func processAutoBid(user: Principal, config: AutoBidConfig) : async () {
    switch (findAuction(config.targetAuctionId)) {
      case (#ok(auction)) {
        let currentHighestBid = List.get(auction.bidHistory, 0);
        
        switch (currentHighestBid) {
          case null {
            if (auction.reservePrice + config.incrementAmount <= config.maxAmount) {
              ignore await makeBid(config.targetAuctionId, auction.reservePrice + config.incrementAmount);
            };
          };
          case (?bid) {
            if (bid.price + config.incrementAmount <= config.maxAmount) {
              ignore await makeBid(config.targetAuctionId, bid.price + config.incrementAmount);
            };
          };
        };
      };
      case (#err(_)) {};
    };
  };

  private func updateCategoryStats(category: Category) : async () {
    categories := List.map<(Category, Nat), (Category, Nat)>(
      categories,
      func((cat, count)) {
        if (cat == category) {
          (cat, count + 1)
        } else {
          (cat, count)
        }
      }
    );
  };

  public query func getCategoryStats() : async [(Category, Nat)] {
    List.toArray(categories)
  };

  public query func getWatchlist(user: Principal) : async [AuctionId] {
    switch (List.find<(Principal, List.List<AuctionId>)>(userWatchlist, func((p, _)) = Principal.equal(p, user))) {
      case null [];
      case (?(_, watchlist)) List.toArray(watchlist);
    }
  };

  private func updateUserWatchlist(user: Principal, auctionId: AuctionId) : async () {
    switch (List.find<(Principal, List.List<AuctionId>)>(
      userWatchlist,
      func((p, _)) = Principal.equal(p, user)
    )) {
      case null {
        userWatchlist := List.push(
          (user, List.push(auctionId, List.nil())),
          userWatchlist
        );
      };
      case (?found) {
        let (_, currentList) = found;
        if (not List.some(currentList, func(id: AuctionId): Bool = id == auctionId)) {
          userWatchlist := List.map<(Principal, List.List<AuctionId>), (Principal, List.List<AuctionId>)>(
            userWatchlist,
            func((p, list)) {
              if (Principal.equal(p, user)) {
                (p, List.push(auctionId, list))
              } else {
                (p, list)
              }
            }
          );
        };
      };
    };
  };

  private func updateUserAutoBids(user: Principal, config: AutoBidConfig) : async () {
    switch (List.find<(Principal, List.List<AutoBidConfig>)>(
      userAutoBids,
      func((p, _)) = Principal.equal(p, user)
    )) {
      case null {
        userAutoBids := List.push(
          (user, List.push(config, List.nil())),
          userAutoBids
        );
      };
      case (?found) {
        let (_, currentConfigs) = found;
        userAutoBids := List.map<(Principal, List.List<AutoBidConfig>), (Principal, List.List<AutoBidConfig>)>(
          userAutoBids,
          func((p, configs)) {
            if (Principal.equal(p, user)) {
              let filteredConfigs = List.filter<AutoBidConfig>(
                configs,
                func(c) = c.targetAuctionId != config.targetAuctionId
              );
              (p, List.push(config, filteredConfigs))
            } else {
              (p, configs)
            }
          }
        );
      };
    };
  };

  public query func getUserAutoBids(user: Principal) : async [AutoBidConfig] {
    switch (List.find<(Principal, List.List<AutoBidConfig>)>(
      userAutoBids,
      func((p, _)) = Principal.equal(p, user)
    )) {
      case null [];
      case (?(_, configs)) List.toArray(configs);
    };
  };

  public shared(msg) func removeAutoBid(auctionId: AuctionId) : async Result<(), AuctionError> {
    switch (List.find<(Principal, List.List<AutoBidConfig>)>(
      userAutoBids,
      func((p, _)) = Principal.equal(p, msg.caller)
    )) {
      case null #err(#InvalidInput);
      case (?found) {
        let (_, currentConfigs) = found;
        userAutoBids := List.map<(Principal, List.List<AutoBidConfig>), (Principal, List.List<AutoBidConfig>)>(
          userAutoBids,
          func((p, configs)) {
            if (Principal.equal(p, msg.caller)) {
              let filteredConfigs = List.filter<AutoBidConfig>(
                configs,
                func(c) = c.targetAuctionId != auctionId
              );
              (p, filteredConfigs)
            } else {
              (p, configs)
            }
          }
        );
        #ok(())
      };
    }
  };

  public shared(msg) func removeFromWatchlist(auctionId: AuctionId) : async Result<(), AuctionError> {
    switch (findAuction(auctionId)) {
      case (#err(error)) return #err(error);
      case (#ok(auction)) {
        // Remove from auction's watchlist
        auction.watchlist := List.filter<Principal>(
          auction.watchlist,
          func(p) = not Principal.equal(p, msg.caller)
        );
        
        // Remove from user's watchlist
        userWatchlist := List.map<(Principal, List.List<AuctionId>), (Principal, List.List<AuctionId>)>(
          userWatchlist,
          func((p, list)) {
            if (Principal.equal(p, msg.caller)) {
              (p, List.filter<AuctionId>(list, func(id) = id != auctionId))
            } else {
              (p, list)
            }
          }
        );
        #ok(())
      };
    }
  };
}