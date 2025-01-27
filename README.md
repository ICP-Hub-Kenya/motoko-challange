
# Motoko Challenge: Enhance a Decentralized Auction Dapp

## Overview
This is a coding challenge for implementing a decentralized auction system on the Internet Computer using Motoko.

## Your Tasks: 
1. Implement a function to store and retrieve auction data using stable variables. This will ensure that auction data persists across canister upgrades.
2. Create a public function that allows users to retrieve a list of all active auctions (those with remaining time > 0).
3. Implement a periodic timer that automatically closes auctions when their remaining time reaches zero. When an auction closes, it should determine the winning bid and update the auction status.
4. Add a new feature that allows the auction creator to set a reserve price. If the highest bid doesn't meet the reserve price when the auction closes, the item should not be sold.
5. Implement a function that allows users to retrieve their bidding history across all auctions.

## Evaluation criteria: 
- Evaluation Criteria
- Correct implementation of the required functionality
- Proper use of Motoko language features
- Code organization and readability
- Handling of edge cases and error conditions
- Efficiency of implemented solutions

## Demo Video
https://github.com/user-attachments/assets/946747e8-31df-4003-a2a8-52d0cd7c5d72
