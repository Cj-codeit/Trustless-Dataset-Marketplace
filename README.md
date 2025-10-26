# Trustless Dataset Marketplace

A decentralized peer-to-peer marketplace for trading curated datasets with escrow protection and consensus-based acceptance.

## Overview

Trustless Dataset Marketplace enables secure trading of AI training datasets. Buyers escrow funds in smart contracts, sellers deliver encrypted datasets, and funds are released after buyer acceptance or dispute resolution.

## Features

- **Dataset Listings**: Sellers create listings with descriptions and pricing
- **Escrow Protection**: Automatic fund escrow during transactions
- **Delivery Tracking**: On-chain delivery confirmation workflow
- **Buyer Acceptance**: Consensus-based payment release
- **Dispute Resolution**: Contract owner arbitration for contested sales
- **Seller Ratings**: Reputation system based on successful deliveries

## Contract Functions

### Public Functions

- `create-listing`: List a dataset for sale
- `purchase-dataset`: Buy a dataset with escrow
- `mark-delivered`: Seller confirms delivery
- `accept-delivery`: Buyer accepts and releases payment
- `raise-dispute`: Contest a delivery
- `resolve-dispute`: Arbitrate disputed sale (owner only)
- `deactivate-listing`: Remove listing from marketplace

### Read-Only Functions

- `get-listing`: Retrieve listing details
- `get-sale`: Get sale transaction info
- `get-escrow-amount`: Check escrowed funds
- `get-seller-rating`: View seller's reputation
- `get-listing-count`: Total listings created
- `get-sale-count`: Total sales completed

## Getting Started
```bash
clarinet contract new dataset-marketplace
clarinet check
clarinet test
```

## Transaction Flow

1. Seller creates listing with dataset hash and price
2. Buyer purchases, funds held in escrow
3. Seller delivers dataset and marks delivered
4. Buyer verifies and accepts delivery
5. Escrow released to seller, reputation updated
6. Disputes handled by contract arbiter if needed