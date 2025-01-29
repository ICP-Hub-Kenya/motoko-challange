# Decentralized Auction System Implementation

This repository contains a complete implementation of a decentralized auction system built on the Internet Computer using Motoko. The system allows users to create auctions, place bids, set reserve prices, and automatically manages auction lifecycles.

## Architecture

The project is structured in a modular way to enhance maintainability and testability:

```
motoko-auction-challange/
├── README.md
├── dfx.json
├── scripts/
│   └── test.sh
├── test/
│   └── auction.test.mo
└── src/
    └── motoko-auction-challange-backend/
        ├── main.mo          # Main actor and entry points
        ├── types.mo         # Type definitions
        ├── auction.mo       # Auction logic
        ├── bid.mo           # Bidding logic
        └── utils.mo         # Utility functions
```

## Features Implemented

### 1. Core Auction Management
- Create new auctions with customizable duration
- Unique auction ID generation
- Persistent auction data storage using stable variables
- Automatic auction closure based on time

### 2. Bidding System
- Place bids with validation
- Track bid history
- Enforce minimum bid requirements
- Record bidder information

### 3. Reserve Price Mechanism
- Set reserve prices for auctions
- Validate auction outcomes against reserve prices
- Only allow creator to modify reserve price

### 4. Query Functions
- Get list of active auctions
- Retrieve detailed auction information
- Access user bid history
- View auction status and remaining time

### 5. Time Management
- Track remaining time for auctions
- Automatic status updates
- Proper handling of auction closure conditions

## Technical Implementation

### Data Persistence
- Used stable variables for auction data
- Implemented proper data structures (List, Buffer)
- Handles data retention across upgrades

### Error Handling
- Comprehensive input validation
- Proper error messages
- Edge case handling
- Type safety throughout

### Testing
- Comprehensive test suite
- Unit tests for core functionality
- Integration tests for complete workflows
- Edge case testing

## How to Run

1. **Start Local Replica**
```bash
dfx start --clean --background
```

2. **Deploy Canisters**
```bash
dfx deploy
```

3. **Run Tests**
```bash
./scripts/test.sh
```

## API Overview

### Creation and Management
```motoko
newAuction(item : Item, duration : Nat) : async AuctionId
addReservePrice(auctionId : AuctionId, price : Nat) : async Result<(), Text>
```

### Bidding
```motoko
makeBid(auctionId : AuctionId, price : Nat) : async Result<(), Text>
```

### Queries
```motoko
getActiveAuctions() : async [AuctionDetails]
getAuctionDetails(auctionId : AuctionId) : async Result<AuctionDetails, Text>
getUserBidHistory(user : Principal) : async [BidInfo]
```

## Testing

The system includes comprehensive tests covering:
1. Auction creation and management
2. Bid placement and validation
3. Reserve price functionality
4. Timer updates and auction closure
5. Edge cases and error conditions

Run tests using:
```bash
./scripts/test.sh
```

## Demo Video

## Demo
Watch the [demo video](https://drive.google.com/file/d/1AbmJTxmFJwJ8gKR95JHOMuVrbQG7OG8E/view?usp=drive_link)
## Challenges and Solutions

1. **Data Persistence**
   - Challenge: Maintaining data across upgrades
   - Solution: Implemented stable variables with proper type definitions

2. **Time Management**
   - Challenge: Handling auction timing accurately
   - Solution: Created robust timer system with proper state management

3. **Modular Architecture**
   - Challenge: Organizing code for maintainability
   - Solution: Separated concerns into distinct modules with clear interfaces

## Future Improvements

1. Add support for multiple auction types
2. Implement auction cancellation mechanism
3. Add bidder notifications
4. Enhance time management with configurable intervals
5. Add support for auction metadata

## Author

[Stella Oiro](https://github.com/Stella-Achar-Oiro)

## License

This project is licensed under the [MIT License](LICENSE).