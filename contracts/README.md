# Half Life Token (HLF)

A unique ERC20 token implementation that creates an engaging elimination game using Chainlink VRF for fair randomization.

## Contract Address
### On Base
```
0x9e351d089c770cc58f08d7bef30bf3aeb761b915
```

## Overview

Half Life Token (HLF) is an experimental token that implements a "last player standing" mechanism. The token starts with a fixed supply and periodically eliminates half of the remaining tokens using verifiable random selection, until only one holder remains.

### Key Features

- **Initial Supply**: 100,000 tokens (with 1 decimal place)
- **Buy Period**: 24-hour initial purchase period
- **Token Price**: $0.01 per token (paid in USDC)
- **Random Elimination**: Uses Chainlink VRF for provably fair token elimination
- **Winner Takes All**: Last holder can claim the entire USDC pool

## How It Works

1. **Buy Phase**
   - Users can purchase tokens during the initial 24-hour period
   - Maximum of 100 unique holders
   - Tokens cost 0.01 USDC each
   - Buy phase ends when either:
     - All tokens are sold
     - 24 hours have passed
     - 100 unique holders is reached

2. **Halving Phase**
   - After each random number generation, half of the remaining tokens are eliminated
   - Selection process uses Chainlink VRF for fair randomization
   - Holders can be eliminated by losing all their tokens
   - Uniswap liquidity is managed separately to maintain trading capability

3. **End Game**
   - Game continues until only 1 token holder remains
   - The winner can claim the entire USDC pool from token sales

## Technical Details

### Smart Contracts

- Built on Solidity 0.8.20
- Inherits from OpenZeppelin's ERC20
- Integrates Chainlink VRF for randomness
- Custom transfer restrictions to prevent gaming the system

### Key Functions

- `buy(uint256 _tokensToBuy)`: Purchase tokens during the buy phase
- `half()`: Triggers the halving mechanism (owner only)
- `cashOut()`: Allows the winner to claim the USDC pool
- `requestRandomWordsForServer()`: Initiates the random number generation

### Security Features

- Randomness provided by Chainlink VRF
- Transfer restrictions to prevent manipulation
- Owner-only functions for critical operations
- Built on audited OpenZeppelin contracts

