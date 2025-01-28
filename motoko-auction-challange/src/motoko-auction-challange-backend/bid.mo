import Types "types";
import List "mo:base/List";
import Time "mo:base/Time";
import Result "mo:base/Result";

module {
    public class BidManager() {
        public func placeBid(
            auction: Types.Auction,
            price: Nat,
            bidder: Principal
        ) : Result.Result<(), Text> {
            if (not auction.isActive) {
                return #err("Auction is not active");
            };
            
            if (auction.remainingTime == 0) {
                return #err("Auction has ended");
            };

            switch (List.last(auction.bidHistory)) {
                case (?highestBid) {
                    if (price <= highestBid.price) {
                        return #err("Bid must be higher than current highest bid");
                    };
                };
                case null {};
            };

            let newBid = {
                price;
                time = Time.now();
                originator = bidder;
            };

            auction.bidHistory := List.push(newBid, auction.bidHistory);
            #ok(());
        };

        public func getHighestBid(auction: Types.Auction) : ?Types.Bid {
            List.last(auction.bidHistory);
        };
    };
};
