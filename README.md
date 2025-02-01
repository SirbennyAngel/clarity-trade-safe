# TradeSafe

A blockchain-powered trade assurance platform built on Stacks.

TradeSafe enables secure peer-to-peer trading by acting as an escrow service. The contract holds funds from the buyer until delivery confirmation, ensuring safe and trustless transactions between parties.

## Features

- Create trade agreements between buyers and sellers
- Secure escrow functionality
- Dispute resolution mechanism
- Configurable trade timeouts
- Release of funds upon mutual agreement
- User rating system with feedback
  - Positive/negative ratings for trade participants
  - Rating comments for detailed feedback
  - Cumulative user rating statistics

## Usage

The contract provides the following main functions:
- create-trade: Create a new trade agreement
- confirm-delivery: Confirm successful delivery (buyer only)
- release-funds: Release escrowed funds (triggered by confirmation)
- dispute-trade: Raise a dispute for resolution
- cancel-trade: Cancel trade if not yet fulfilled
- submit-rating: Submit rating and feedback for trade participant
- get-user-rating: View user's cumulative rating statistics

### Rating System

After a trade is completed, both buyer and seller can rate each other using:
- Positive (1) or negative (0) rating
- Optional comment providing detailed feedback
- Ratings are stored permanently and contribute to user's reputation score
