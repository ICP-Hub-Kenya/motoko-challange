# Decentralized Auction System

A decentralized auction system built on the Internet Computer using Motoko.

## Features

- Create and manage auctions
- Place bids on active auctions
- Automatic auction closing
- Reserve price system
- Track bidding history

## Quick Start

### Prerequisites

- Install `dfx`
- Node.js and npm

### Setup

```bash
# Start local network
dfx start --background

# Deploy canister
dfx deploy motoko-auction-challange-backend
```

### Usage Examples

#### Create Auction
```bash
dfx canister call motoko-auction-challange-backend newAuction '(
  record {
    title = "Test Item";
    description = "Test item description";
    image = blob "ABCD"
  },
  3600000000000,  # 1 hour
  100             # reserve price
)'
```

#### View Active Auctions
```bash
dfx canister call motoko-auction-challange-backend getActiveAuctions
```

#### Place Bid
```bash
dfx canister call motoko-auction-challange-backend makeBid '(1, 150)'
```

## Implementation Notes

- Time values are in nanoseconds
- Images are stored as Blobs
- Auction status updates every minute
- State persists across canister upgrades

## Testing

Run test commands from the terminal to verify functionality:
```bash
# Test sequence
dfx canister call motoko-auction-challange-backend newAuction '(...)'
dfx canister call motoko-auction-challange-backend getActiveAuctions
dfx canister call motoko-auction-challange-backend makeBid '(1, 150)'
dfx canister call motoko-auction-challange-backend getUserBidHistory
```