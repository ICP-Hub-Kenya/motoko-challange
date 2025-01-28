import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import List "mo:base/List";
import Error "mo:base/Error";
import Types "../src/motoko-auction-challange-backend/types";
import AuctionModule "../src/motoko-auction-challange-backend/auction";
import BidModule "../src/motoko-auction-challange-backend/bid";
import Utils "../src/motoko-auction-challange-backend/utils";

actor class AuctionTest() {
    let auctionManager = AuctionModule.AuctionManager();
    let bidManager = BidModule.BidManager();

    // Test data
    let testItem : Types.Item = {
        title = "Test Item";
        description = "Test Description";
        image = ""; // Empty blob for testing
    };

    let testPrincipal = Principal.fromText("2vxsx-fae");

    // Helper function to create test auction
    func createTestAuction() : Types.Auction {
        auctionManager.createAuction(0, testItem, 3600, testPrincipal);
    };

    public func runTests() : async Text {
        var passed = 0;
        var failed = 0;

        // Test 1: Create Auction
        try {
            let auction = createTestAuction();
            assert auction.id == 0;
            assert auction.item == testItem;
            assert auction.remainingTime == 3600;
            assert auction.isActive == true;
            passed += 1;
            Debug.print("✓ Test 1: Create Auction - Passed");
        } catch err {
            failed += 1;
            Debug.print("✗ Test 1: Create Auction - Failed: " # Error.message(err));
        };

        // Test 2: Place Valid Bid
        try {
            let auction = createTestAuction();
            switch(bidManager.placeBid(auction, 100, testPrincipal)) {
                case (#ok(_)) {
                    passed += 1;
                    Debug.print("✓ Test 2: Place Valid Bid - Passed");
                };
                case (#err(msg)) {
                    failed += 1;
                    Debug.print("✗ Test 2: Place Valid Bid - Failed: " # msg);
                };
            };
        } catch err {
            failed += 1;
            Debug.print("✗ Test 2: Place Valid Bid - Failed with exception: " # Error.message(err));
        };

        // Test 3: Reject Lower Bid
        try {
            let auction = createTestAuction();
            // Place initial bid
            ignore bidManager.placeBid(auction, 100, testPrincipal);
            // Try lower bid
            switch(bidManager.placeBid(auction, 50, testPrincipal)) {
                case (#err(_)) {
                    passed += 1;
                    Debug.print("✓ Test 3: Reject Lower Bid - Passed");
                };
                case (#ok(_)) {
                    failed += 1;
                    Debug.print("✗ Test 3: Reject Lower Bid - Failed: Lower bid was accepted");
                };
            };
        } catch err {
            failed += 1;
            Debug.print("✗ Test 3: Reject Lower Bid - Failed with exception: " # Error.message(err));
        };

        // Test 4: Set Reserve Price
        try {
            let auction = createTestAuction();
            switch(auctionManager.setReservePrice(auction, 500, testPrincipal)) {
                case (#ok(_)) {
                    assert auction.reservePrice == ?500;
                    passed += 1;
                    Debug.print("✓ Test 4: Set Reserve Price - Passed");
                };
                case (#err(msg)) {
                    failed += 1;
                    Debug.print("✗ Test 4: Set Reserve Price - Failed: " # msg);
                };
            };
        } catch err {
            failed += 1;
            Debug.print("✗ Test 4: Set Reserve Price - Failed with exception: " # Error.message(err));
        };

        // Test 5: Update Timer
        try {
            let auction = createTestAuction();
            auction.remainingTime := 1;
            let _ = auctionManager.updateTimer(auction);
            assert auction.remainingTime == 0;
            assert auction.isActive == false;
            passed += 1;
            Debug.print("✓ Test 5: Update Timer - Passed");
        } catch err {
            failed += 1;
            Debug.print("✗ Test 5: Update Timer - Failed with exception: " # Error.message(err));
        };

        // Test 6: Get Auction Details
        try {
            let auction = createTestAuction();
            let details = Utils.auctionToDetails(auction);
            assert details.id == auction.id;
            assert details.item == auction.item;
            assert details.remainingTime == auction.remainingTime;
            passed += 1;
            Debug.print("✓ Test 6: Get Auction Details - Passed");
        } catch err {
            failed += 1;
            Debug.print("✗ Test 6: Get Auction Details - Failed with exception: " # Error.message(err));
        };

        // Return test results
        "Tests completed: " # debug_show(passed) # " passed, " # debug_show(failed) # " failed"
    };
};