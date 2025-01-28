import List "mo:base/List";
import Timer "mo:base/Timer";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

actor AuctionDapp {
  type Item = {
    title : Text;
    description : Text;
    image : Blob;
  };

  type Bid = {
    price : Nat;
    time : Nat;
    originator : Principal.Principal;
  };

  type AuctionId = Nat;

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    var reservePrice : Nat;
    creator : Principal.Principal;
    var isClosed : Bool;
    var winningBid : ?Bid;
    var isItemSold : Bool;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
  };

  stable var stableAuctions : [Auction] = [];
  stable var auctions = List.nil<Auction>();
  stable var idCounter : AuctionId = 0;

  // Task 1: A function to store auction data using stable variables
  public shared (msg) func newAuction(
    item : Item,
    duration : Nat,
    reservePrice : Nat,
  ) : async () {
    let id = newAuctionId();
    let bidHistory = List.nil<Bid>();
    var winningBid : ?Bid = null;
    let newAuction = {
      id;
      item;
      var bidHistory;
      var remainingTime = duration;
      var reservePrice = reservePrice;
      creator = msg.caller;
      var isClosed = false;
      var winningBid = winningBid;
      var isItemSold = false;
    };
    auctions := List.push<Auction>(newAuction, auctions);
  };

  // Task 4: A new feature that allows the auction creator to set a reserve price.
  // If the highest bid doesn't meet the reserve price when the auction closes, the item should not be sold.

  //Task 1.2: A function to retrieve auction data using stable variables
  public query func getAllAuctionData() : async [AuctionDetails] {
    List.toArray(
      List.map<Auction, AuctionDetails>(
        auctions,
        func(a : Auction) : AuctionDetails {
          {
            id = a.id;
            isClosed = a.isClosed;
            isItemSold = a.isItemSold;
            winningBid = a.winningBid;
            item = a.item;
            bidHistory = List.toArray(a.bidHistory);
            remainingTime = a.remainingTime;
            reservePrice = a.reservePrice;
          };
        },
      )
    );
  };

  // Task 2: A public function that allows users to retrieve a list of all active auctions (those with remaining time > 0)
  public query func getActiveAuctions() : async [AuctionDetails] {
    List.toArray(
      List.mapFilter(
        auctions,
        func(a : Auction) : ?AuctionDetails {
          if (a.remainingTime <= 0) null else ?{
            item = a.item;
            bidHistory = List.toArray(a.bidHistory);
            remainingTime = a.remainingTime;
            reservePrice = a.reservePrice;
          };
        },
      )
    );
  };

  //A function allowing its users to create a bid
  public shared (msg) func makeBid(
    auctionId : AuctionId,
    price : Nat,
  ) : async () {
    let originator = msg.caller;

    //The function below will be implemented in future times for full proof authorization from the frontend
    // if (Principal.isAnonymous(originator)) {
    //   return Debug.trap("Anonymous callers are not allowed to bid");
    // };

    let auction = findAuction(auctionId);

    if (price < minimumPrice(auction)) {
      Debug.trap("Bid price is too low");
    };

    if (auction.remainingTime == 0) {
      Debug.trap("Auction is closed");
    };

    let newBid = { price; time = auction.remainingTime; originator };
    auction.bidHistory := List.push(newBid, auction.bidHistory);

  };

  // Task 3: Closes auctions when their remaining time reaches zero.
  // func closeAuction(auctionId : AuctionId) : async () {
  //   let auction = findAuction(auctionId);
  //   var winningBid : ?Bid = null;

  //   //First close the auction by updating the isClosed boolen element
  //   auctions := List.map(
  //     auctions,
  //     func(a : Auction) : Auction {
  //       if (a.remainingTime <= 0) {
  //         // Step 1: Close the auction
  //         {
  //           id = a.id;
  //           item = a.item;
  //           var bidHistory = a.bidHistory;
  //           var remainingTime = a.remainingTime;
  //           var reservePrice = a.reservePrice;
  //           var isClosed = true;
  //           var winningBid = winningBid;
  //           var isItemSold = false;
  //         };

  //         // Step 2: After closing the auction, check the following
  //         // If the highest bid doesn't meet the reserve price when the auction closes, the item should not be sold.
  //         switch (winningBid) {
  //           case null {
  //             Debug.trap("No winning bid not found for auction " # debug_show (a.id));
  //           };
  //           case (?winningBid) {
  //             //since there is a winning bid,
  //             if (a.reservePrice > winningBid.price) {
  //               // since the reserve price has not been reached by the winning bid,
  //               // set the item as not sould but keep the auction closed
  //               {
  //                 id = a.id;
  //                 item = a.item;
  //                 var bidHistory = a.bidHistory;
  //                 var remainingTime = a.remainingTime;
  //                 var reservePrice = a.reservePrice;
  //                 creator = a.creator;
  //                 var isClosed = true;
  //                 var winningBid = winningBid;
  //                 var isItemSold = false;
  //               };
  //             } else {
  //               {
  //                 id = a.id;
  //                 item = a.item;
  //                 var bidHistory = a.bidHistory;
  //                 var remainingTime = a.remainingTime;
  //                 var reservePrice = a.reservePrice;
  //                 creator = a.creator;
  //                 var isClosed = true;
  //                 var winningBid = winningBid;
  //                 var isItemSold = true;
  //               };
  //             };
  //           };
  //         }

  //       } else {
  //         a;
  //       };
  //     },
  //   );

  //   switch (winningBid) {
  //     case null {
  //       Debug.print("Auction " # debug_show (auctionId) # " closed.");
  //     };
  //     case (?winner) {
  //       Debug.print(
  //         "Auction " # debug_show (auctionId) # " closed. Winner: " #
  //         debug_show (winner.originator) # " with bid: " #
  //         debug_show (winner.price)
  //       );

  //     };
  //   };

  // };

  // Task 3: Closes auctions when their remaining time reaches zero.
  func closeAuction(auctionId : AuctionId) : async () {
    let auction = findAuction(auctionId);
    var winningBid : ?Bid = null;

    if (auction.remainingTime > 0) {
      Debug.print("Auction is not yet closed");
    };

    for (bid in List.toIter(auction.bidHistory)) {
      switch (winningBid) {
        case null { winningBid := ?bid };
        case (?currentWinningBid) {
          if (bid.price > currentWinningBid.price) {
            winningBid := ?bid;
          };
        };
      };
    };

    let isItemSold = switch (winningBid) {
      case null false;
      case (?bid) bid.price >= auction.reservePrice;
    };

    auctions := List.map(
      auctions,
      func(a : Auction) : Auction {
        if (a.id == auctionId) {
          {
            id = auctionId;
            item = a.item;
            var bidHistory = a.bidHistory;
            var remainingTime = 0;
            var reservePrice = a.reservePrice;
            creator = a.creator;
            var isClosed = true;
            var winningBid = winningBid;
            var isItemSold = isItemSold;
            // var isClosed = true;
            // var winningBid = winningBid;
            // var isItemSold = isItemSold;
          };
        } else {
          a;
        };
      },
    );

  };

  //// Task 4: A function that allows the auction creator to set a reserve price. I
  public shared (msg) func setAuctionReservePrice(auctionId : AuctionId, reservePrice : Nat) : async () {

    let auction = findAuction(auctionId);

    //First check is the creator of the auction is the caller first
    let caller = msg.caller;

    if (auction.creator == caller) {
      //update the auction array with an updated auction details
      auctions := List.map(
        auctions,
        func(a : Auction) : Auction {
          if (a.id == auctionId) {
            {
              id = auctionId;
              item = a.item;
              var bidHistory = a.bidHistory;
              var remainingTime = a.remainingTime;
              var reservePrice = reservePrice;
              creator = a.creator;
              var isClosed = a.isClosed;
              var winningBid = a.winningBid;
              var isItemSold = a.isItemSold;
            };
          } else {
            a;
          };
        },
      );
    } else {
      //since the caller is not the owner of the auction, deny access
      Debug.trap("Caller is not authorized to assign a reserve price to the auction. The caller is not the owner of the auction.");
    }

  };

  //Retrieving the details of a given auction using its Auction ID
  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {

    if (auctionId <= 0) {
      Debug.print("The action ID provided is invalid. It needs to be greater than 0");
    };

    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    {
      id = auction.id;
      item = auction.item;
      bidHistory;
      remainingTime = auction.remainingTime;
      reservePrice = auction.reservePrice;
      isClosed = auction.isClosed;
      winningBid = auction.winningBid;
      isItemSold = auction.isItemSold;
    };
  };

  //Task 5: A function that allows users to retrieve their bidding history across all auctions.
  public query func getUserBids(user : Principal) : async [Bid] {
    var bids : List.List<Bid> = List.nil();
    List.iterate(
      auctions,
      func(a : Auction) {
        List.iterate(
          a.bidHistory,
          func(b : Bid) {
            if (b.originator == user) {
              bids := List.push(b, bids);
            };
          },
        );
      },
    );
    List.toArray(bids);
  };

  //HELPER FUNCTIONS
  /// function to retrieve the minimum price for an auction's next bid; the next bid must be one unit of currency larger than the last bid:
  func minimumPrice(auction : Auction) : Nat {
    switch (auction.bidHistory) {
      case null 1;
      case (?(lastBid, _)) lastBid.price + 1;
    };
  };

  //FIND A GIVEN AUCTION BY THE AUCTION ID
  func findAuction(auctionId : AuctionId) : Auction {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch (result) {
      case null Debug.trap("Inexistent auction ID");
      case (?auction) auction;
    };
  };

  /// Define a function to generating a new auction:
  func newAuctionId() : AuctionId {
    let id = idCounter;
    idCounter += 1;
    id;
  };

  //A fucntion to get the principal of the active user
  public query (msg) func whoami() : async Text {
    Principal.toText(msg.caller);
  };

  //get the latest auction id
  public query func getLatestAuctionId() : async Nat {
    idCounter;
  };

  //A function to check if the reserve price is met:
  public query func isReservePriceMet(auctionId : AuctionId) : async Bool {
    let auction = findAuction(auctionId);
    switch (auction.bidHistory) {
      case null false;
      case (?(highestBid, _)) highestBid.price >= auction.reservePrice;
    };
  };

  //A function to get the winning bid for a given auction
  public query func getAuctionWinningBid(auctionId : AuctionId) : async ?Bid {
    let auction = findAuction(auctionId);

    auction.winningBid;
  };

  // Task 3: a periodic timer that automatically closes auctions when their remaining time reaches zero.
  // When an auction closes, it determines the winning bid and update the auction status.
  func tick() : async () {
    for (auction in List.toIter(auctions)) {
      if (auction.remainingTime > 0) {
        auction.remainingTime -= 1;
      };

      if (auction.remainingTime == 0) {
        await closeAuction(auction.id);
      };
    };
  };

  /// Execute a timer that calls the tick function every second:
  let timer = Timer.recurringTimer(#seconds 1, tick);

  system func preupgrade() {
    stableAuctions := List.toArray(auctions);
  };

  system func postupgrade() {
    auctions := List.fromArray(stableAuctions);

    //To save memory, we need to clear the storage for the moment
    stableAuctions := [];
  };

};
