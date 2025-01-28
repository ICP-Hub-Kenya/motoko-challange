import List "mo:base/List";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";

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

  type AuctionStatus = {
    #Active;
    #Closed;
    #Reserved;
  };

  type Auction = {
    id : AuctionId;
    item : Item;
    var bidHistory : List.List<Bid>;
    var remainingTime : Nat;
    creator : Principal;
    reservePrice : Nat;
    var status : AuctionStatus;
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    status : AuctionStatus;
    reservePrice : Nat;
  };

  stable var auctions = List.nil<Auction>();
  stable var idCounter = 0;
  stable var userBidHistory = List.nil<(Principal, List.List<(AuctionId, Bid)>)>();

  func findAuction(auctionId : AuctionId) : Auction {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId);
    switch (result) {
      case null Debug.trap("Inexistent id");
      case (?auction) auction;
    };
  };

  func isAuctionActive(auction : Auction) : Bool {
    auction.remainingTime > 0 and auction.status == #Active;
  };

  public shared(message) func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async AuctionId {
      let newId = idCounter + 1;
      idCounter += 1;

      let newAuction : Auction = {
          id = newId;
          item = item;
          var bidHistory = List.nil<Bid>();
          var remainingTime = duration;
          creator = message.caller;
          reservePrice = reservePrice;
          var status = #Active;
      };

      auctions := List.push(newAuction, auctions);
      newId
  };

  public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(auctions, isAuctionActive);
    List.toArray(List.map<Auction, AuctionDetails>(activeAuctions, func (auction) {
        {
            item = auction.item;
            bidHistory = List.toArray(List.reverse(auction.bidHistory));
            remainingTime = auction.remainingTime;
            status = auction.status;
            reservePrice = auction.reservePrice;
        }
    }));
  };

  public shared(message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
    let auction = findAuction(auctionId);
    
    assert(isAuctionActive(auction));
    
    let currentHighestBid = List.head(auction.bidHistory);
    switch (currentHighestBid) {
        case (?bid) assert(price > bid.price);
        case null assert(price >= auction.reservePrice);
    };

    let newBid : Bid = {
        price = price;
        time = Time.now();
        originator = message.caller;
    };

    auction.bidHistory := List.push(newBid, auction.bidHistory);
    
    updateUserBidHistory(message.caller, auctionId, newBid);
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    {
        item = auction.item;
        bidHistory = List.toArray(List.reverse(auction.bidHistory));
        remainingTime = auction.remainingTime;
        status = auction.status;
        reservePrice = auction.reservePrice;
    }
  };

  public query func getUserBidHistory(user : Principal) : async [(AuctionId, Bid)] {
    switch (List.find<(Principal, List.List<(AuctionId, Bid)>)>(
        userBidHistory,
        func((p, _)) = Principal.equal(p, user)
    )) {
        case null [];
        case (?(_, history)) List.toArray(history);
    };
  };

  func updateUserBidHistory(user : Principal, auctionId : AuctionId, bid : Bid) {
    let userHistory = List.find<(Principal, List.List<(AuctionId, Bid)>)>(
        userBidHistory,
        func((p, _)) = Principal.equal(p, user)
    );

    switch (userHistory) {
        case null {
            userBidHistory := List.push(
                (user, List.push((auctionId, bid), List.nil())),
                userBidHistory
            );
        };
        case (?(_, history)) {
            userBidHistory := List.map<(Principal, List.List<(AuctionId, Bid)>), (Principal, List.List<(AuctionId, Bid)>)>(
                userBidHistory,
                func((p, h)) {
                    if (Principal.equal(p, user)) {
                        (p, List.push((auctionId, bid), h))
                    } else {
                        (p, h)
                    };
                }
            );
        };
    };
  };

  system func timer(setTimer : Nat -> ()) {
      setTimer(1_000_000_000); // Set timer to run every 1 second
      auctions := List.map<Auction, Auction>(auctions, func (auction) {
          if (isAuctionActive(auction)) {
              if (auction.remainingTime > 0) {
                  auction.remainingTime -= 1;
              };

              if (auction.remainingTime == 0) {
                  let highestBid = List.head(auction.bidHistory);
                  switch (highestBid) {
                      case (?bid) {
                          if (bid.price >= auction.reservePrice) {
                              auction.status := #Closed;
                          } else {
                              auction.status := #Reserved;
                          };
                      };
                      case null {
                          auction.status := #Reserved;
                      };
                  };
              };
          };
          auction
      });
  };

}