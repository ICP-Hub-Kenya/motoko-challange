import List "mo:base/List";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
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
  };

  type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
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

  // Implementation of newAuction
  public func newAuction(item : Item, duration : Nat) : async () {
    idCounter += 1;
    let newAuction : Auction = {
      id = idCounter;
      item = item;
      var bidHistory = List.nil<Bid>();
      var remainingTime = duration;
    };
    auctions := List.push(newAuction, auctions);
  };

  public query func getAuctionDetails(auctionId : AuctionId) : async AuctionDetails {
    let auction = findAuction(auctionId);
    let bidHistory = List.toArray(List.reverse(auction.bidHistory));
    { 
      item = auction.item; 
      bidHistory; 
      remainingTime = auction.remainingTime 
    }
  };

  // Implementation of makeBid
  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async () {
    let auction = findAuction(auctionId);
    
    // Check if auction is still active
    if (auction.remainingTime == 0) {
      Debug.trap("Auction has ended");
    };

    // Check if bid is higher than previous bids
    switch (List.get(auction.bidHistory, 0)) {
      case null { };  // First bid, no need to check
      case (?prevBid) {
        if (price <= prevBid.price) {
          Debug.trap("Bid must be higher than current highest bid");
        };
      };
    };

    let newBid : Bid = {
      price;
      time = Int.abs(Time.now());
      originator = message.caller;
    };

    auction.bidHistory := List.push(newBid, auction.bidHistory);

  };
  // Added test functions
  public func testAuction() : async Text {
    // Test setup
    let testItem : Item = {
      title = "Test Item";
      description = "Test Description";
      image = ""; // Empty blob for testing
    };

    // Test 1: Create new auction
    await newAuction(testItem, 3600);
    let auctionDetails = await getAuctionDetails(idCounter);
    
    if (auctionDetails.item.title != "Test Item") {
      return "Test 1 failed: Auction creation";
    };

    // Test 2: Make first bid
    try {
      await makeBid(idCounter, 100);
      let details = await getAuctionDetails(idCounter);
      switch (List.get(List.fromArray(details.bidHistory), 0)) {
        case null { return "Test 2 failed: Bid not recorded" };
        case (?bid) {
          if (bid.price != 100) {
            return "Test 2 failed: Incorrect bid price";
          };
        };
      };
    } catch (e) {
      return "Test 2 failed: " # Debug.trap("Error making bid");
    };

    // Test 3: Make lower bid (should fail)
    try {
      await makeBid(idCounter, 50);
      return "Test 3 failed: Lower bid should not be accepted";
    } catch (e) {
      // This is expected
    };

    return "All tests passed!";
  };
  // Helper function to get current highest bid
  public query func getHighestBid(auctionId : AuctionId) : async ?Bid {
    let auction = findAuction(auctionId);
    List.get(auction.bidHistory, 0)
  };
}