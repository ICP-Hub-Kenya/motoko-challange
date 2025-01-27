# Motoko Auction System

A decentralized auction system built on the Internet Computer using Motoko.

## Features

- Create auctions with reserve prices
- Place bids on active auctions
- Automatic auction closure
- View auction history and status
- Track your bidding history
- Data persistence across upgrades

## Quick Start

Make sure you have `dfx` installed.

```bash
# Start the local replica
dfx start --background

# Deploy the canister
dfx deploy

# Create a new auction
dfx canister call motoko-auction-challange-backend newAuction '(record { title = "Test Item"; description = "A test item"; image = blob "test" }, 3600, 100)'

# Place a bid
dfx canister call motoko-auction-challange-backend makeBid '(1, 150)'

# View auction details
dfx canister call motoko-auction-challange-backend getAuctionDetails '(1)'

# View user bid history
dfx canister call motoko-auction-challange-backend getUserBidHistory

# View highest bid in the system
dfx canister call motoko-auction-challange-backend getHighestBidInSystem
```

