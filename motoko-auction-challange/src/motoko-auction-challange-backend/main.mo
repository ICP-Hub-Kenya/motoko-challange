import Result "mo:base/Result";
import List "mo:base/List";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

actor {
  // Define custom error types for the auction system
  type Error = {
    #InvalidPrice; // Error for invalid price
    #AuctionNotFound; // Error when an auction is not found
    #AuctionNotActive; // Error when trying to interact with a non-active auction
    #BidTooLow; // Error for a bid that is too low
    #InvalidDuration; // Error for invalid auction duration
  };

  // Define the possible statuses of an auction
  type AuctionStatus = {
    #active; // Auction is currently active
    #closed; // Auction is closed
    #cancelled; // Auction is cancelled
  };

  // Define the structure for an item in the auction
  type Item = {
    title : Text; // Title of the item
    description : Text; // Description of the item
    image : Blob; // Image representing the item
  };

  // Define the structure for a bid in the auction
  type Bid = {
    price : Nat; // Bid price
    time : Int; // Time of the bid
    originator : Principal; // The principal (user) who made the bid
  };

  type AuctionId = Nat; // Auction ID type, used to uniquely identify auctions

  // Define the structure for an auction
  type Auction = {
    id : AuctionId; // Auction ID
    item : Item; // The item being auctioned
    var bidHistory : List.List<Bid>; // List of bids in the auction
    var remainingTime : Nat; // Remaining time for the auction
    var status : AuctionStatus; // Status of the auction
    var winningBid : ?Bid; // The winning bid (if any)
    reservePrice : Nat; // The reserve price for the auction
  };

  // Stable storage variables to keep track of auctions and auction IDs
  stable var auctions = List.nil<Auction>(); // List of all auctions
  stable var idCounter = 0; // Counter for generating unique auction IDs

  // Function to find an auction by ID
  func findAuction(auctionId : AuctionId) : Result.Result<Auction, Error> {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId); // Search for auction by ID
    switch (result) {
      case null #err(#AuctionNotFound); // Auction not found
      case (?auction) #ok(auction); // Auction found, return it
    };
  };

  // Function to create a new auction
  public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async Result.Result<AuctionId, Error> {
    if (duration == 0) { return #err(#InvalidDuration); }; // Invalid duration
    if (reservePrice == 0) { return #err(#InvalidPrice); }; // Invalid reserve price
    
    let auctionId = idCounter; // Use the current ID counter as the auction ID
    let newAuction : Auction = {
      id = auctionId;
      item = item; // Set the auction item
      var bidHistory = List.nil<Bid>(); // Initialize an empty bid history
      var remainingTime = duration; // Set the remaining time for the auction
      var status = #active; // Set the auction status to active
      var winningBid = null; // No winning bid initially
      reservePrice = reservePrice; // Set the reserve price
    };
    auctions := List.push(newAuction, auctions); // Add the new auction to the list
    idCounter += 1; // Increment the auction ID counter
    #ok(auctionId); // Return the created auction's ID
  };

  // Function to place a bid on an auction
  public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Error> {
    switch (findAuction(auctionId)) { // Find the auction by ID
      case (#err(e)) { return #err(e) }; // If auction not found, return error
      case (#ok(auction)) {
        if (auction.status != #active or auction.remainingTime == 0) { // Auction must be active and not expired
          return #err(#AuctionNotActive); // Return error if auction is not active
        };

        let firstBid = List.get(auction.bidHistory, 0); // Get the first bid in the auction history
        switch (firstBid) {
          case null { // No bids yet
            if (price < auction.reservePrice) { // Check if bid is below the reserve price
              return #err(#BidTooLow); // Return error if bid is too low
            };
          };
          case (?prevBid) { // There are previous bids
            if (price <= prevBid.price) { // Bid must be higher than the previous bid
              return #err(#BidTooLow); // Return error if bid is too low
            };
          };
        };

        let newBid : Bid = {
          price = price; // Set the price of the bid
          time = Time.now(); // Set the time of the bid
          originator = message.caller; // Set the originator (caller) of the bid
        };

        auction.bidHistory := List.push(newBid, auction.bidHistory); // Add the new bid to the bid history
        #ok(); // Return success
      };
    };
  };
  
  // Function to close an auction when its time expires
  private func closeAuction(auction : Auction) {
    if (auction.remainingTime == 0 and auction.status == #active) { // Auction is expired and still active
      auction.status := #closed; // Mark the auction as closed
      let firstBid = List.get(auction.bidHistory, 0); // Get the first bid
      switch (firstBid) {
        case null { }; // No bids, no winner
        case (?bid) {
          if (bid.price >= auction.reservePrice) { // Check if the winning bid meets the reserve price
            auction.winningBid := ?bid; // Set the winning bid
          };
        };
      };
    };
  };

  // Function to update the remaining time of all auctions
  public func updateAuctionTimes() : async () {
    auctions := List.map<Auction, Auction>( // Iterate over all auctions
      auctions,
      func (auction) {
        if (auction.remainingTime > 0 and auction.status == #active) { // Only update active auctions
          auction.remainingTime -= 1; // Decrease the remaining time
          if (auction.remainingTime == 0) { // If time is up, close the auction
            closeAuction(auction);
          };
        };
        auction; // Return the updated auction
      }
    );
  };

  // Start the recurring timer when the actor is upgraded or initialized
  public func post_upgrade() : async () {
    // Initialize the recurring timer to update auction times every 60 seconds
    let _ = Timer.recurringTimer<system>(
      #seconds(60),
      func() : async () {
        await updateAuctionTimes(); // Update auction times
        for (auction in List.toArray(auctions).vals()) { // Iterate over all auctions
          closeAuction(auction); // Close each auction that has expired
        };
      }
    );
  }
}
