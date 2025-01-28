import Debug "mo:base/Debug";
import List "mo:base/List";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Timer "mo:base/Timer";

actor {
    // Define the interface of the main canister we're testing
    let mainCanister = actor ("bkyz2-fmaaa-aaaaa-qaaaq-cai") : actor {
        newAuction : shared (Item, Nat, Nat) -> async Result.Result<(), Text>;
        getAuctionDetails : shared (Nat) -> async AuctionDetails;
        getAllAuctions : shared () -> async [AuctionDetails];
        getActiveAuctions : shared () -> async [AuctionDetails];
        makeBid : shared (Nat, Nat) -> async Result.Result<(), Text>;
        getBiddingHistory : shared () -> async Result.Result<[(AuctionId, Bid)], Text>;
        cleanupTestData : shared () -> async Result.Result<(), Text>;
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
        status : AuctionStatus;
        winner : ?Principal;
    };

    type Bid = {
        price : Nat;
        time : Nat;
        originator : Principal;
    };

    type AuctionStatus = {
        #active;
        #closed;
    };

    type AuctionId = Nat;

    public func testCreateAuction() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "Test Auction";
            description = "This is a test auction item";
            image = testImage;
        };
        let initialActiveAuctions = await mainCanister.getAllAuctions();
        let initialCount = initialActiveAuctions.size();

        let result = await mainCanister.newAuction(testItem, 3600, 0);

        if (Result.isOk(result)) {
            let details = await mainCanister.getAuctionDetails(initialCount);
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

        let result = await mainCanister.newAuction(testItem, 3600, 0);

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

        let result = await mainCanister.newAuction(testItem, 3600, 0);

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

        let result1 = await mainCanister.newAuction(testItem1, 3600, 0);
        let result2 = await mainCanister.newAuction(testItem2, 3600, 0);

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

        let result1 = await mainCanister.newAuction(activeItem, 3600, 0);
        let result2 = await mainCanister.newAuction(expiredItem, 0, 0);

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

        let createResult = await mainCanister.newAuction(testItem, 3600, 0);

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

    public func testReservePriceAuction() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;
        let testItem = {
            title = "Reserve Price Test Auction";
            description = "Testing reserve price functionality";
            image = testImage;
        };

        let auctions = await mainCanister.getAllAuctions();
        let newAuctionId = auctions.size();

        // Create auction with reserve price of 1000 and short duration
        let createResult = await mainCanister.newAuction(testItem, 2, 1000);

        var testResults = "\n=== Reserve Price Tests ===\n";

        // Test multiple bids
        let bid1Result = await mainCanister.makeBid(newAuctionId, 500); // Below reserve
        let bid2Result = await mainCanister.makeBid(newAuctionId, 800); // Below reserve
        let bid3Result = await mainCanister.makeBid(newAuctionId, 1200); // Above reserve

        // Get final auction details
        let finalDetails = await mainCanister.getAuctionDetails(newAuctionId);

        // Verify bid history
        if (finalDetails.bidHistory.size() == 3) {
            testResults := testResults # "✅ All bids recorded successfully\n";

            let highestBid = finalDetails.bidHistory[2].price; // Changed from [0] to [2]
            if (highestBid >= 1000) {
                testResults := testResults # "✅ Highest bid meets reserve price\n";
            } else {
                testResults := testResults # "❌ Highest bid below reserve price\n";
            };
        } else {
            testResults := testResults # "❌ Not all bids were recorded\n";
        };

        testResults;
    };

    public func testBiddingHistory() : async Text {
        let testImage : Blob = "\FF\D8\FF\E0" : Blob;

        // Create two test auctions
        let testItem1 = {
            title = "History Test Auction 1";
            description = "First auction for history test";
            image = testImage;
        };

        let testItem2 = {
            title = "History Test Auction 2";
            description = "Second auction for history test";
            image = testImage;
        };

        let auctions = await mainCanister.getAllAuctions();
        let auction1Id = auctions.size();
        let auction2Id = auction1Id + 1;

        var testResults = "\n=== Bidding History Tests ===\n";

        // Test 1: Check initial state (should return error for no bids)
        let initialHistory = await mainCanister.getBiddingHistory();
        if (Result.isErr(initialHistory)) {
            testResults := testResults # "✅ Correctly identified no initial bids\n";
        } else {
            testResults := testResults # "❌ Should have returned error for no initial bids\n";
        };

        // Test 2: Create auctions and place bids
        let result1 = await mainCanister.newAuction(testItem1, 3600, 100);
        let result2 = await mainCanister.newAuction(testItem2, 3600, 200);

        if (Result.isOk(result1) and Result.isOk(result2)) {
            let bid1Result = await mainCanister.makeBid(auction1Id, 150);
            let bid2Result = await mainCanister.makeBid(auction2Id, 250);

            if (Result.isOk(bid1Result) and Result.isOk(bid2Result)) {
                testResults := testResults # "✅ Successfully placed test bids\n";
            } else {
                testResults := testResults # "❌ Failed to place test bids\n";
            };
        };

        // Test 3: Check final bidding history
        let finalHistory = await mainCanister.getBiddingHistory();
        if (Result.isOk(finalHistory)) {
            switch (finalHistory) {
                case (#ok(bids)) {
                    if (bids.size() >= 2) {
                        testResults := testResults # "✅ Successfully retrieved bidding history with multiple bids\n";
                    } else {
                        testResults := testResults # "❌ Incomplete bidding history retrieved\n";
                    };
                };
                case (#err(_)) {};
            };
        } else {
            let errorMsg = Result.mapErr<[(AuctionId, Bid)], Text, Text>(finalHistory, func(x : Text) : Text { x });
            testResults := testResults # "❌ Failed to retrieve bidding history: " # debug_show (errorMsg) # "\n";
        };

        testResults;
    };

    public func runAllTests() : async Text {
        let test1 = await testCreateAuction();
        let cleanup = await mainCanister.cleanupTestData();

        let test2 = await testEmptyTitleAuction();
        let cleanup2 = await mainCanister.cleanupTestData();

        let test3 = await testEmptyDescriptionAuction();
        let _cleanup3 = await mainCanister.cleanupTestData();

        let test4 = await testGetAllAuctions();
        let cleanup4 = await mainCanister.cleanupTestData();

        let test5 = await testGetActiveAuctions();
        let cleanup5 = await mainCanister.cleanupTestData();

        let test6 = await testBiddingFeatures();
        let cleanup6 = await mainCanister.cleanupTestData();

        let test7 = await testReservePriceAuction();
        let cleanup7 = await mainCanister.cleanupTestData();

        let test8 = await testBiddingHistory();
        let cleanup8 = await mainCanister.cleanupTestData();

        "\n=== Test Results ===\n" #
        "1. " # test1 # "\n" #
        "2. " # test2 # "\n" #
        "3. " # test3 # "\n" #
        "4. " # test4 # "\n" #
        "5. " # test5 # "\n" #
        "6. " # test6 # "\n" #
        "7. " # test7 # "\n" #
        "8. " # test8 # "\n" #
        "====================";
    };

};
