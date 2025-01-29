#!/bin/bash

# test.sh
echo "Starting Auction System Tests..."

# Deploy test canister
dfx deploy --mode=reinstall test/auction.test

# Run tests
dfx canister call auction_test runTests

echo "Tests completed!"