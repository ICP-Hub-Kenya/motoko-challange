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
        getAllAuctions : shared () -> async [AuctionDetails];
        getActiveAuctions : shared () -> async [AuctionDetails];
        makeBid : shared (Nat, Nat) -> async Result.Result<(), Text>;
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

    public func testGetAllAuctions() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem1 = {
            title = "Test Auction 1";
            description = "First test item";
            image = testImage;
        };
        let testItem2 = {
            title = "Test Auction 2";
            description = "Second test item";
            image = testImage;
        };

        let result1 = await mainCanister.newAuction(testItem1, 3600);
        let result2 = await mainCanister.newAuction(testItem2, 3600);

        if (Result.isOk(result1) and Result.isOk(result2)) {
            let auctions = await mainCanister.getAllAuctions();

            if (auctions.size() >= 2) {
                return "✅ Successfully retrieved all auctions";
            } else {
                return "❌ Failed to retrieve all auctions. Found: " # debug_show (auctions.size()) # " auctions";
            };
        } else {
            return "❌ Failed to create test auctions";
        };
    };

    public func testGetActiveAuctions() : async Text {
        // Get initial count of active auctions
        let initialActiveAuctions = await mainCanister.getActiveAuctions();
        let initialCount = initialActiveAuctions.size();

        let testImage : Blob = "\FF\D8\FF\E0" : Blob;

        // Create one active auction
        let activeItem = {
            title = "Active Auction";
            description = "This auction is still running";
            image = testImage;
        };

        // Create one expired auction
        let expiredItem = {
            title = "Expired Auction";
            description = "This auction has ended";
            image = testImage;
        };

        let result1 = await mainCanister.newAuction(activeItem, 3600);
        let result2 = await mainCanister.newAuction(expiredItem, 0);

        let newActiveAuctions = await mainCanister.getActiveAuctions();

        if (newActiveAuctions.size() == initialCount + 1) {
            return "✅ Active auctions count increased by exactly one";
        } else {
            return "❌ Active auctions count incorrect. Expected: " # debug_show (initialCount + 1) #
            " but got: " # debug_show (newActiveAuctions.size());
        };
    };

    public func testBiddingFeatures() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "Test Auction for Bidding";
            description = "Test item for bidding features";
            image = testImage;
        };

        // Create auction and get its ID from the current auction count
        let auctions = await mainCanister.getAllAuctions();
        let newAuctionId = auctions.size();

        let createResult = await mainCanister.newAuction(testItem, 3600);

        var testResults = "\n=== Bidding Tests Results ===\n";

        // Test valid bid
        let bidResult = await mainCanister.makeBid(newAuctionId, 100);
        if (Result.isOk(bidResult)) {
            testResults := testResults # "✅ Valid bid accepted\n";
        } else {
            let errorMsg = Result.mapErr<(), Text, Text>(bidResult, func(x) { x });
            testResults := testResults # "❌ Valid bid rejected: " # debug_show (errorMsg) # "\n";
        };

        // Test lower bid acceptance
        let lowerBidResult = await mainCanister.makeBid(newAuctionId, 50);
        if (Result.isOk(lowerBidResult)) {
            testResults := testResults # "✅ Lower bid accepted as expected\n";
        } else {
            let errorMsg = Result.mapErr<(), Text, Text>(lowerBidResult, func(x) { x });
            testResults := testResults # "❌ Lower bid rejected: " # debug_show (errorMsg) # "\n";
        };

        // Test non-existent auction
        let nonExistentResult = await mainCanister.makeBid(999, 200);
        if (Result.isErr(nonExistentResult)) {
            testResults := testResults # "✅ Bid on non-existent auction correctly rejected\n";
        } else {
            testResults := testResults # "❌ Bid on non-existent auction incorrectly accepted\n";
        };

        testResults;
    };

    public func runAllTests() : async Text {
        let test1 = await testCreateAuction();
        let test2 = await testEmptyTitleAuction();
        let test3 = await testEmptyDescriptionAuction();
        let test4 = await testGetAllAuctions();
        let test5 = await testGetActiveAuctions();
        let test6 = await testBiddingFeatures();

        "\n=== Test Results ===\n" #
        "1. " # test1 # "\n" #
        "2. " # test2 # "\n" #
        "3. " # test3 # "\n" #
        "4, " # test4 # "\n" #
        "5, " # test5 # "\n" #
        "6, " # test6 # "\n" #
        "====================";
    };
};
