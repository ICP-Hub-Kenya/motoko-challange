import Debug "mo:base/Debug";
import List "mo:base/List";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";

actor {
    // Define the interface of the main canister we're testing
    let mainCanister = actor ("bkyz2-fmaaa-aaaaa-qaaaq-cai") : actor {
        newAuction : shared (Item, Nat) -> async ();
        getAuctionDetails : shared (Nat) -> async AuctionDetails;
    };

    // Define the types we need
    type Item = {
        title : Text;
        description : Text;
        image : Blob;
    };

    type AuctionDetails = {
        item : Item;
        bidHistory : [Bid];
        remainingTime : Nat;
    };

    type Bid = {
        price : Nat;
        time : Nat;
        originator : Principal;
    };

    public func testCreateAuction() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "Test Auction";
            description = "This is a test auction item";
            image = testImage;
        };

        await mainCanister.newAuction(testItem, 3600);
        let details = await mainCanister.getAuctionDetails(0);

        Debug.print(details.item.title);
        Debug.print(details.item.description);
        if (details.item.image.size() > 0) {
            Debug.print("image is here");
        };

        if (
            details.item.title == testItem.title and
            details.item.description == testItem.description
        ) {
            "Auction created successfully";
        } else {
            "Failed to create auction";
        };
    };
};
