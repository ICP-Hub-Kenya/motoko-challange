# Motoko Auction Challenge

This project implements a decentralized auction system on the Internet Computer using Motoko. Users can create auctions, place bids, and participate in a transparent bidding process.

## Features

- Create new auctions with custom items
- Place bids on active auctions
- View auction details and bid history
- Automatic time management for auction duration
- Data persistence across canister upgrades

## Prerequisites

- [DFX SDK](https://sdk.dfinity.org/docs/quickstart/local-quickstart.html) (v0.24.3 or later)
- Node.js 14 or later
- Git

## Setup and Installation

1. Clone the repository:
```bash
git checkout -b solution/your-name
cd motoko-auction-challange
```

2. Install dependencies:
```bash
npm install
```

3. Start the local Internet Computer replica:
```bash
dfx start --clean --background
```

4. Deploy the canister:
```bash
dfx deploy
```

## Testing

1. Create a new auction:
```bash
dfx canister call motoko-auction-challange-backend newAuction '(record { title = "Test Item"; description = "Test Description"; image = blob "" }, 3600)'
```

2. Place a bid:
```bash
dfx canister call motoko-auction-challange-backend makeBid '(1, 100)'
```

3. View auction details:
```bash
dfx canister call motoko-auction-challange-backend getAuctionDetails '(1)'
```

4. Check highest bid:
```bash
dfx canister call motoko-auction-challange-backend getHighestBid '(1)'
```

5. Run the automated test suite:
```bash
dfx canister call motoko-auction-challange-backend testAuction
```

## Submission Guidelines

1. Fork the repository

2. Create a new branch:
```bash
git checkout -b solution/your-name
```

3. Implement the required functionality:
   - Auction creation
   - Bidding mechanism
   - Time management
   - Data persistence

4. Test your implementation:
   - Deploy locally
   - Test all features
   - Record a video demo
   - Verify data persistence across upgrades

5. Create your submission:
   - Push your solution to your fork
   - Create a Pull Request to the main repository
   - Include in the PR description:
     - Brief explanation of your implementation
     - Any additional features or improvements
     - Link to your demo video

## Project Structure

```
motoko-auction-challange/
├── dfx.json
├── package.json
├── src/
│   └── motoko-auction-challange-backend/
│       └── main.mo
└── tests/
```

## Implementation Details

The auction system implements the following core functionality:

1. **Auction Creation**
   - Title, description, and image for items
   - Customizable auction duration
   - Unique auction IDs

2. **Bidding System**
   - Bid validation
   - Bid history tracking
   - Highest bid tracking

3. **Time Management**
   - Countdown timer for auctions
   - Automatic auction closure

4. **Data Persistence**
   - State management across upgrades
   - Bid history preservation
