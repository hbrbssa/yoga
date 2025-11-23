# Yoga - Uniswap V4 Position Manager

An improved ERC721 position manager for Uniswap V4 that uses a red-black tree to efficiently manage and merge adjacent liquidity ranges.

## Overview

Yoga is a smart contract that wraps Uniswap V4 liquidity positions into ERC721 NFTs, enabling users to manage  multi-range positions with automatic range merging and splitting. Each NFT represents a collection of liquidity positions that can be dynamically modified while maintaining optimal on-chain storage efficiency.

## Key Features

- **ERC721 Position Tokens**: Each liquidity position is represented as a transferable NFT
- **Automatic Range Merging**: Adjacent ranges with identical liquidity are automatically combined to save gas
- **Red-Black Tree Storage**: Uses self-balancing tree for efficient tick enumeration and range operations
- **Multi-Range Positions**: Single NFT can manage multiple non-overlapping tick ranges
- **Slippage Protection**: Built-in limits for maximum token amounts spent
- **Native ETH Support**: Handles both ERC20 tokens and native ETH

## Architecture

### Core Components

- **Position Management**: Red-black tree tracks tick boundaries for each NFT
- **Liquidity Operations**: Atomic add/remove/modify operations with automatic merging
- **Uniswap V4 Integration**: Direct integration with PoolManager via unlock callback pattern
- **Reentrancy Protection**: Transient storage-based reentrancy guards

### Data Structures

```solidity
struct TokenInfo {
    RedBlackTreeLib.Tree subPositions;  // Tree of tick boundaries
    PoolKey key;                         // Associated Uniswap V4 pool
}

struct SimpleModifyLiquidityParams {
    int24 tickLower;
    int24 tickUpper;
    int256 liquidityDelta;
}
```

## Usage

### Minting a Position

```solidity
function mint(
    PoolKey calldata key,
    SimpleModifyLiquidityParams calldata params,
    uint128 currency0Max,
    uint128 currency1Max
) external payable returns (uint256 tokenId, BalanceDelta delta)
```

Creates a new NFT with initial liquidity in the specified tick range.

**Parameters:**
- `key`: Uniswap V4 pool identifier (currency0, currency1, fee, tickSpacing, hooks)
- `params`: Tick range and liquidity amount
- `currency0Max/currency1Max`: Maximum tokens to spend (slippage protection)

### Modifying a Position

```solidity
function modify(
    address payable recipient,
    uint256 tokenId,
    SimpleModifyLiquidityParams calldata params,
    uint128 currency0Max,
    uint128 currency1Max
) external payable returns (BalanceDelta delta)
```

Adds or removes liquidity from an existing position. Automatically handles range splitting and merging.

**Range Operations:**
- **Extend**: Add liquidity beyond existing ranges (auto-merges if adjacent)
- **Split**: Divide existing range into two separate ranges
- **Merge**: Automatically combines ranges with matching liquidity
- **Remove**: Burns NFT when all liquidity is removed

### Querying Position Data

```solidity
function getKey(uint256 tokenId) external view returns (
    Currency currency0,
    Currency currency1,
    uint24 fee,
    int24 tickSpacing,
    IHooks hooks
)

function getTicks(uint256 tokenId) external view returns (int24[] memory)
```

## Technical Details

### Range Merging Logic

The contract automatically merges adjacent ranges when:
1. Adding liquidity that extends an existing range
2. Modifying liquidity to match adjacent ranges
3. Removing liquidity that results in matching adjacent ranges

This optimization significantly reduces storage costs and gas consumption for managing multi-range positions.

### Tick Tree Implementation

- Uses red-black tree for O(log n) insertions, deletions, and lookups
- Ticks stored as offset values (tick + 887273) for positive-only tree keys
- Automatic tree balancing maintains efficient operations
- NFT automatically burned when tree becomes empty

### Unlock Callback Pattern

Integrates with Uniswap V4's unlock mechanism for atomic multi-operation batches:

```solidity
function unlockCallback(bytes calldata data) external onlyPoolManager
```

All liquidity modifications are batched and settled atomically within a single unlock.

## Dependencies

- **Solady**: ERC721, SafeTransferLib, ReentrancyGuardTransient, RedBlackTreeLib
- **Uniswap V4**: IPoolManager, StateLibrary, Position, PoolKey types
- **Solidity**: ^0.8.30

## Constants

- `POOL_MANAGER`: `0x1F98400000000000000000000000000000000004`
- `_MIN_TICK`: `-887272` (Uniswap V4 minimum tick)

## License

MIT


# Future work

* MultiCall mode to create arbitrary liquidity distributions in a single transaction
* Flag to settle in ERC6909 or ERC20 tokens
* ERC721 enumerability
* Support for hooks that require hookData
* Clean up `_populateActions`
* Stateful invariant testing
* `burn` (with pagination for gas limits)
* Fancy `tokenURI` images
* Permit2 support
* Easy function for collecting/compounding swap fees
* Allow creation of non-adjacent liquidity ranges
* Pool initialization on `mint`
