# Motoko Auction Challenge

This project implements a decentralized auction system on the Internet Computer using Motoko. Users can create auctions, place bids, and participate in a transparent bidding process.

## Features

- Create new auctions with custom items
- Place bids on active auctions
- View auction details and bid history
- Automatic time management for auction duration
- Data persistence across canister upgrades

## Demo

[Watch Demo Video](./demo.mp4)

## Setup and Installation

1. Clone the repository:

git checkout -b solution/john_nalwa
cd motoko-auction-challange


2. Install dependencies:

npm install


3. Start the local Internet Computer replica:

dfx start --clean --background


4. Deploy the canister:

dfx deploy


## Testing

1. Create a new auction:

dfx canister call motoko-auction-challange-backend newAuction '(record { title = "Test Item"; description = "Test Description"; image = blob "" }, 3600)'


2. Place a bid:

dfx canister call motoko-auction-challange-backend makeBid '(1, 100)'


3. View auction details:

dfx canister call motoko-auction-challange-backend getAuctionDetails '(1)'


4. Check highest bid:

dfx canister call motoko-auction-challange-backend getHighestBid '(1)'


5. Run the automated test suite:

dfx canister call motoko-auction-challange-backend testAuction

