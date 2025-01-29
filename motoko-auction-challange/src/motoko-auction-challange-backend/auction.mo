import Types "types";
import List "mo:base/List";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

module {
    public class AuctionManager() {
        public func createAuction(
            id: Nat,
            item: Types.Item,
            duration: Nat,
            creator: Principal
        ) : Types.Auction {
            {
                id;
                item;
                var bidHistory = List.nil<Types.Bid>();
                var remainingTime = duration;
                var reservePrice = null;
                creator;
                var isActive = true;
            }
        };

        public func updateTimer(auction: Types.Auction) : Bool {
            if (auction.isActive and auction.remainingTime > 0) {
                auction.remainingTime -= 1;
                if (auction.remainingTime == 0) {
                    auction.isActive := false;
                };
                true;
            } else {
                false;
            };
        };

        public func setReservePrice(
            auction: Types.Auction,
            price: Nat,
            caller: Principal
        ) : Result.Result<(), Text> {
            if (caller != auction.creator) {
                #err("Only auction creator can set reserve price");
            } else if (not auction.isActive) {
                #err("Cannot modify inactive auction");
            } else {
                auction.reservePrice := ?price;
                #ok(());
            };
        };
    };
};
