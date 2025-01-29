# Motoko Challenge: Enhance a Decentralized Auction Dapp

# motoko-auction-challange

## Overview
The Motoko Auction Challenge is a decentralized auction system built using the Motoko programming language. This project allows users to create auctions, place bids, and retrieve auction details, all while ensuring a secure and efficient bidding process.

## Implementation Overview
This auction system features:
- **Auction Types**: Defined types for `Auction`, `Item`, `Bid`, and `AuctionStatus` to ensure a structured and type-safe auction system.
- **Core Functionality**:
  - **Creating Auctions**: Users can create new auctions with specified items and durations using the `newAuction` function.
  - **Bidding Mechanism**: Users can place bids on active auctions with the `makeBid` function, ensuring that bids are valid and higher than the current minimum price.
  - **Auction Details**: The `getAuctionDetails` function retrieves detailed information about a specific auction, including bid history and the highest bid.
  - **Active Auctions**: The `getActiveAuctions` function allows users to retrieve a list of currently active auctions.
  - **Auction Closure**: A timer function automatically closes auctions when the time expires and determines the highest bid.

## Additional Features and Improvements
- **Error Handling**: Improved error handling across various functions to provide users with appropriate feedback when interacting with the auction system.
- **User Experience**: Enhanced the overall user experience by ensuring that all functions are intuitive and easy to use.

## Demo Video
A video demonstrating the complete functionality of the auction system, including creating auctions, placing bids, and retrieving auction details, can be found here: [Demo Video](link_to_your_video).

## Getting Started

### Prerequisites
- [DFX](https://dfinity.org/docs/developers-guide/dfx) - The DFINITY SDK for building and deploying applications on the Internet Computer.
- Node.js and npm (for frontend development).

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/motoko-auction-challange.git
   cd motoko-auction-challange
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the local DFX environment:
   ```bash
   dfx start --background
   ```

4. Deploy the canisters:
   ```bash
   dfx deploy
   ```

5. Start the frontend development server:
   ```bash
   npm start
   ```

### Usage
- **Create a New Auction**: Use the `newAuction` function to create an auction with an item and duration.
- **Place a Bid**: Use the `makeBid` function to place a bid on an active auction.
- **Get Active Auctions**: Use the `getActiveAuctions` function to retrieve a list of currently active auctions.
- **Get Auction History**: Use the `getHistory` function to view the bidding history for a specific auction.

## Testing
- All features have been tested locally to ensure functionality.
- Unit tests are included for critical functions.

## Future Work
- Implement a frontend interface for easier user interaction.
- Add notifications for auction winners and bid updates.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
