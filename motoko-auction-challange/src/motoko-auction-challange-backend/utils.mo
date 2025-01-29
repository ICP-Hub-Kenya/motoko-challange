import Types "types";
import List "mo:base/List";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

module {
    public func auctionToDetails(auction: Types.Auction) : Types.AuctionDetails {
        {
            id = auction.id;
            item = auction.item;
            bidHistory = List.toArray(List.reverse(auction.bidHistory));
            remainingTime = auction.remainingTime;
            reservePrice = auction.reservePrice;
            creator = auction.creator;
            isActive = auction.isActive;
        }
    };

    public func filterActiveAuctions(auctions: List.List<Types.Auction>) : [Types.AuctionDetails] {
        let activeAuctions = List.filter<Types.Auction>(
            auctions,
            func(a) { a.isActive and a.remainingTime > 0 }
        );
        
        Array.map<Types.Auction, Types.AuctionDetails>(
            List.toArray(activeAuctions),
            auctionToDetails
        );
    };
};
