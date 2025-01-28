import List "mo:base/List";
import T "Types";

module {
    /// Convert Auction model to AuctionDetails model
    public func auctionToAuctionDetails(auction : T.Auction) : T.AuctionDetails {
        {
            item = auction.item;
            bidHistory = List.toArray(List.reverse(auction.bidHistory));
            remainingTime = auction.remainingTime;
            reservePrice = auction.reservePrice;
            winningBid = auction.winningBid;
        };
    };
};
