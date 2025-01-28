import Debug "mo:base/Debug";
import List "mo:base/List";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";

actor {
    // Define the interface of the main canister we're testing
    let mainCanister = actor ("bkyz2-fmaaa-aaaaa-qaaaq-cai") : actor {
        newAuction : shared (Item, Nat) -> async Result.Result<(), Text>;
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

        let result = await mainCanister.newAuction(testItem, 3600);

        if (Result.isOk(result)) {
            let details = await mainCanister.getAuctionDetails(0);
            if (
                details.item.title == testItem.title and
                details.item.description == testItem.description
            ) {
                return "✅ Valid auction created successfully";
            } else {
                return "❌ Auction details don't match input";
            };
        } else {
            let errorMsg = Result.mapErr<(), Text, Text>(result, func(x) { x });
            return "❌ Failed to create valid auction: " # debug_show (errorMsg);
        };
    };

    public func testEmptyTitleAuction() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "";
            description = "This is a test auction item";
            image = testImage;
        };

        let result = await mainCanister.newAuction(testItem, 3600);

        if (Result.isOk(result)) {
            return "❌ Should not create auction with empty title";
        } else {
            let errorMsg = Result.mapErr<(), Text, Text>(result, func(x) { x });
            if (debug_show (errorMsg) == "#err(\"Title cannot be empty\")") {
                return "✅ Empty title correctly rejected";
            } else {
                return "❌ Unexpected error message: " # debug_show (errorMsg);
            };
        };
    };

    public func testEmptyDescriptionAuction() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "Test Auction";
            description = "";
            image = testImage;
        };

        let result = await mainCanister.newAuction(testItem, 3600);

        if (Result.isOk(result)) {
            return "❌ Should not create auction with empty description";
        } else {
            let errorMsg = Result.mapErr<(), Text, Text>(result, func(x) { x });
            if (debug_show (errorMsg) == "#err(\"Description cannot be empty\")") {
                return "✅ Empty description correctly rejected";
            } else {
                return "❌ Unexpected error message: " # debug_show (errorMsg);
            };
        };
    };

    public func runAllTests() : async Text {
        let test1 = await testCreateAuction();
        let test2 = await testEmptyTitleAuction();
        let test3 = await testEmptyDescriptionAuction();

        "\n=== Test Results ===\n" #
        "1. " # test1 # "\n" #
        "2. " # test2 # "\n" #
        "3. " # test3 # "\n" #
        "====================";
    };
};
