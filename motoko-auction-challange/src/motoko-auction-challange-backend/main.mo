import Types "types";
import Auction "auction";
import Bid "bid";
import Utils "utils";
import List "mo:base/List";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

actor {
    stable var auctions = List.nil<Types.Auction>();
    stable var idCounter = 0;

    let auctionManager = Auction.AuctionManager();
    let bidManager = Bid.BidManager();

    public shared(msg) func newAuction(item : Types.Item, duration : Nat) : async Types.AuctionId {
        let auction = auctionManager.createAuction(idCounter, item, duration, msg.caller);
        auctions := List.push(auction, auctions);
        idCounter += 1;
        auction.id;
    };

    public shared(msg) func makeBid(auctionId : Types.AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch (List.find<Types.Auction>(auctions, func(a) { a.id == auctionId })) {
            case null { #err("Auction not found") };
            case (?auction) {
                bidManager.placeBid(auction, price, msg.caller);
            };
        };
    };

    public query func getActiveAuctions() : async [Types.AuctionDetails] {
        Utils.filterActiveAuctions(auctions);
    };

    public shared(msg) func addReservePrice(auctionId : Types.AuctionId, price : Nat) : async Result.Result<(), Text> {
        switch (List.find<Types.Auction>(auctions, func(a) { a.id == auctionId })) {
            case null { #err("Auction not found") };
            case (?auction) {
                auctionManager.setReservePrice(auction, price, msg.caller);
            };
        };
    };

    public func updateAuctionTimers() : async () {
        auctions := List.map<Types.Auction, Types.Auction>(
            auctions,
            func(auction) {
                let _ = auctionManager.updateTimer(auction);
                auction;
            }
        );
    };

    public query func getAuctionDetails(auctionId : Types.AuctionId) : async Result.Result<Types.AuctionDetails, Text> {
        switch (List.find<Types.Auction>(auctions, func(a) { a.id == auctionId })) {
            case null { #err("Auction not found") };
            case (?auction) {
                #ok(Utils.auctionToDetails(auction));
            };
        };
    };
};

