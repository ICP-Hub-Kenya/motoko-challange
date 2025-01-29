import Result "mo:base/Result";
import List "mo:base/List";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

// Define custom error types for the auction system
actor {
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

// Structure for auction details with bid history
type AuctionDetails = {
    item : Item; // Item in the auction
    bidHistory : [Bid]; // Bid history (in reverse order)
    remainingTime : Nat; // Remaining time for the auction
    status : AuctionStatus; // Auction status
    winningBid : ?Bid; // Winning bid (if any)
    reservePrice : Nat; // Reserve price
};

// Stable storage variables to keep track of auctions and auction IDs
stable var auctions = List.nil<Auction>(); // List of all auctions
stable var idCounter = 0; // Counter for generating unique auction IDs

// Function to find an auction by ID
func findAuction(auctionId : AuctionId) : Result.Result<Auction, Error> {
    let result = List.find<Auction>(auctions, func auction = auction.id == auctionId); // Search for auction by ID
    switch (result) {
        case null { #err(#AuctionNotFound) }; // Auction not found
        case (?auction) { #ok(auction) }; // Auction found, return it
    };
};

// Function to create a new auction
public func newAuction(item : Item, duration : Nat, reservePrice : Nat) : async Result.Result<AuctionId, Error> {
    if (duration == 0) { return #err(#InvalidDuration); }; // Invalid duration
    if (reservePrice == 0) { return #err(#InvalidPrice); }; // Invalid reserve price
    
    let auctionId = idCounter; // Use the current ID counter as the auction ID
    idCounter += 1; // Increment the counter for future auctions
    
    let newAuction : Auction = {
        id = auctionId;
        item = item; // Set the auction item
        var bidHistory = List.nil<Bid>(); // Empty bid history
        var remainingTime = duration; // Set the remaining time
        var status = #active; // Set the initial status to active
        var winningBid = null; // No winning bid initially
        reservePrice = reservePrice; // Set the reserve price
    };

    auctions := List.push(newAuction, auctions); // Add the new auction to the list
    #ok(auctionId) // Return the auction ID
};

// Function to get auction details by ID
public query func getAuctionDetails(auctionId : AuctionId) : async Result.Result<AuctionDetails, Error> {
    switch (findAuction(auctionId)) {
        case (#err(e)) { return #err(e) }; // If auction not found, return error
        case (#ok(auction)) {
            // Return auction details, converting the bid history to an array and reversing it
            #ok({
                item = auction.item;
                bidHistory = List.toArray(List.reverse(auction.bidHistory)); // Reverse bid history for correct order
                remainingTime = auction.remainingTime;
                status = auction.status;
                winningBid = auction.winningBid;
                reservePrice = auction.reservePrice;
            })
        };
    };
};

// Function to place a bid in an auction
public shared (message) func makeBid(auctionId : AuctionId, price : Nat) : async Result.Result<(), Error> {
    switch (findAuction(auctionId)) {
        case (#err(e)) { return #err(e) }; // If auction not found, return error
        case (#ok(auction)) {
            if (auction.status != #active) { return #err(#AuctionNotActive); }; // Ensure the auction is active
            if (auction.remainingTime == 0) { return #err(#AuctionNotActive); }; // Ensure the auction is still running
            
            // Check if the bid is too low compared to the previous bid
            let firstBid = List.get(auction.bidHistory, 0);
            switch (firstBid) {
                case null { 
                    if (price < auction.reservePrice) {
                        return #err(#BidTooLow);
                    };
                };
                case (?prevBid) {
                    if (price <= prevBid.price) {
                        return #err(#BidTooLow);
                    };
                };
            };

            // Create the new bid
            let newBid : Bid = {
                price = price;
                time = Time.now(); // Use the current time for the bid
                originator = message.caller; // Use the caller as the originator
            };

            // Add the new bid to the auction's bid history
            auction.bidHistory := List.push(newBid, auction.bidHistory);
            #ok() // Return success
        };
    };
};

// Periodically check auction times and close expired auctions
private func closeAuction(auction : Auction) {
    if (auction.remainingTime == 0 and auction.status == #active) {
        auction.status := #closed; // Close the auction when time runs out
        let firstBid = List.get(auction.bidHistory, 0); // Get the first bid (last bid in history)
        switch (firstBid) {
            case null { /* No bids */ };
            case (?bid) {
                if (bid.price >= auction.reservePrice) {
                    auction.winningBid := ?bid; // Set the winning bid if the reserve price is met
                };
            };
        };
    };
};

public func updateAuctionTimes() : async () {
    auctions := List.map<Auction, Auction>(
        auctions,
        func (auction) {
            if (auction.remainingTime > 0 and auction.status == #active) {
                auction.remainingTime -= 1; // Decrease the remaining time
                if (auction.remainingTime == 0) {
                    closeAuction(auction); // Close the auction if time is up
                };
            };
            auction
        }
    );
};

// Initialize timer for periodic auction updates
private let auctionTimer = Timer.recurringTimer<system>(
    #seconds(60), // Check every minute
    func() : async () {
        await updateAuctionTimes();
        // Close expired auctions
        for (auction in List.toArray(auctions).vals()) {
            closeAuction(auction);
        };
    }
);

// Query function to get active auctions
public query func getActiveAuctions() : async [AuctionDetails] {
    let activeAuctions = List.filter<Auction>(
        auctions,
        func (auction) { auction.remainingTime > 0 and auction.status == #active }
    );
    List.toArray(
        List.map<Auction, AuctionDetails>(
            activeAuctions,
            func (auction) {
                {
                    item = auction.item;
                    bidHistory = List.toArray(List.reverse(auction.bidHistory));
                    remainingTime = auction.remainingTime;
                    status = auction.status;
                    winningBid = auction.winningBid;
                    reservePrice = auction.reservePrice;
                }
            }
        )
    )
};
}