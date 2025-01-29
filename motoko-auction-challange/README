# Auction System on Motoko

This is a decentralized auction system built on the Internet Computer (ICP) using the Motoko programming language. The system allows users to create auctions, place bids, and automatically close auctions when their duration expires. Auctions have a reserve price, and if the highest bid does not meet the reserve price, the item will not be sold.

## Features

1. **Create Auctions**: Users can create new auctions for items, setting a reserve price and auction duration.
2. **Place Bids**: Users can place bids on active auctions, provided that the bid meets the reserve price and is higher than previous bids.
3. **Automatic Auction Closure**: Auctions close automatically once their remaining time reaches zero. The auction creator can set a reserve price, and if the highest bid doesn't meet the reserve price, the auction item is not sold.
4. **Bid History**: Each auction maintains a history of bids, recording the bid price, time, and the bidder's principal.
5. **Periodic Timer**: A recurring timer updates the auction status every 60 seconds to check if any auction has expired, and it closes them accordingly.

## Types and Definitions

- **Error Types**:
  - `#InvalidPrice`: Raised when an invalid price is encountered.
  - `#AuctionNotFound`: Raised when an auction with the given ID is not found.
  - `#AuctionNotActive`: Raised when an auction is not active (either closed or canceled).
  - `#BidTooLow`: Raised when the bid is lower than the current bid or reserve price.
  - `#InvalidDuration`: Raised when an auction's duration is invalid.

- **AuctionStatus**:
  - `#active`: Indicates that the auction is still ongoing.
  - `#closed`: Indicates that the auction has closed.
  - `#cancelled`: Indicates that the auction has been canceled.

- **Item**: Represents an item in the auction with a title, description, and image.
  
- **Bid**: Represents a bid in the auction, including the price, time, and the principal (user) who made the bid.

- **Auction**: Represents an auction, which contains the item, bid history, remaining time, status, winning bid, and the reserve price.

- **AuctionId**: A unique identifier for each auction.

## Functions

### 1. **newAuction(item: Item, duration: Nat, reservePrice: Nat)**

Creates a new auction with the specified item, duration, and reserve price.

- **Parameters**:
  - `item`: The item being auctioned.
  - `duration`: The duration of the auction in seconds.
  - `reservePrice`: The minimum price at which the item can be sold.
  
- **Returns**: A `Result.Result<AuctionId, Error>` indicating success with the auction ID or an error.

### 2. **makeBid(auctionId: AuctionId, price: Nat)**

Allows a user to place a bid on an auction. The bid must be higher than the previous bid and meet the reserve price.

- **Parameters**:
  - `auctionId`: The ID of the auction.
  - `price`: The bid price.

- **Returns**: A `Result.Result<(), Error>` indicating success or an error.

### 3. **getActiveAuctions()**

Returns a list of all active auctions that have remaining time greater than zero.

- **Returns**: A list of active auctions.

### 4. **updateAuctionTimes()**

Updates the remaining time for all active auctions. If an auction's time has expired, it will be automatically closed.

- **Returns**: Nothing (it runs asynchronously).

### 5. **post_upgrade()**

This function is called when the actor is upgraded or initialized. It sets up a recurring timer that updates auction times every 60 seconds.

- **Returns**: Nothing (it sets up a timer).

### 6. **closeAuction(auction: Auction)**

Closes an auction when the remaining time reaches zero. It checks if the highest bid meets the reserve price and determines the winning bid.

- **Parameters**:
  - `auction`: The auction to close.

- **Returns**: Nothing.

## Usage

### Creating an Auction

To create a new auction, call the `newAuction` function with the necessary parameters, such as the item details, auction duration, and reserve price.

```motoko
let item = { title = "Item 1"; description = "A great item"; image = Blob.fromArray([0, 1, 2, 3]) };
let duration = 3600;  // 1 hour in seconds
let reservePrice = 100;
let auctionId = await newAuction(item, duration, reservePrice);
```

### Placing a Bid

To place a bid, call the `makeBid` function with the auction ID and the bid price.

```motoko
let auctionId = 0;  // Example auction ID
let bidPrice = 150;
await makeBid(auctionId, bidPrice);
```

### Retrieving Active Auctions

To retrieve all active auctions, call the `getActiveAuctions` function.

```motoko
let activeAuctions = await getActiveAuctions();
```

### Timer and Auction Closure

The `post_upgrade` function sets up a timer to check and close auctions periodically. The timer runs every 60 seconds, ensuring that expired auctions are closed automatically.

## Known Issues

- If an auction's time is updated manually, the automatic closure logic may not work as expected if the remaining time is not managed correctly.
- The system assumes that `Blob` for images is provided, but in a real-world application, this would need to be handled appropriately.

## Conclusion

This auction system offers a simple decentralized marketplace for users to bid on items. The system manages auction durations, bids, and the reserve price automatically. Auctions are securely closed when their time runs out, and the highest bid is selected if it meets the reserve price.

## Demo Video
Watch the demo video to see the auction system in action:

https://drive.google.com/file/d/1SxtNkPX57W0xCH_gU9F19pDMgWdt-Hw4/view?usp=sharing
