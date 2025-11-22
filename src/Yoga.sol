// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {IERC165} from "@forge-std/interfaces/IERC165.sol";

import {ERC721} from "@solady/tokens/ERC721.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ReentrancyGuardTransient} from "@solady/utils/ReentrancyGuardTransient.sol";
import {RedBlackTreeLib} from "@solady/utils/RedBlackTreeLib.sol";

import {BalanceDelta} from "@uniswapv4/types/BalanceDelta.sol";
import {PoolKey} from "@uniswapv4/types/PoolKey.sol";
import {ModifyLiquidityParams} from "@uniswapv4/types/PoolOperation.sol";
import {IPoolManager} from "@uniswapv4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswapv4/interfaces/IUnlockCallback.sol";

//import {MultiCallContext} from "lib/MultiCallContext.sol";

struct SimpleModifyLiquidityParams {
    // the lower and upper tick of the position
    int24 tickLower;
    int24 tickUpper;
    // how to modify the liquidity
    int256 liquidityDelta;
}

struct SubPositions {
    RedBlackTreeLib.Tree tree;
    uint24 lastTick;
}

library CurrencySafeTransferLib {
    using SafeTransferLib for address;

    function safeTransferFrom(Currency token, address from, address to, uint256 amount) internal {
        return Currency.unwrap(token).safeTransferFrom(from, to, amount);
    }
}

contract Yoga is IERC165, IUnlockCallback, ERC721, /*, MultiCallContext */ ReentrancyGuardTransient {
    using CurrencySafeTransferLib for Currency;
    using RedBlackTreeLib for RedBlackTreeLib.Tree;
    using RedBlackTreeLib for bytes32;

    IPoolManager public constant POOL_MANAGER = IPoolManager(0x1F98400000000000000000000000000000000004);

    int24 private constant _MIN_TICK = -887272;

    uint256 public nextTokenid = 1;

    mapping(uint256 => SubPositions) private _subPositions;

    function _tickToTreeKey(int24 tick) private pure returns (uint24) {
        unchecked {
            return uint24(tick - (_MIN_TICK - 1));
        }
    }

    function _treeKeyToTick(uint24 treeKey) private pure returns (int24) {
        unchecked {
            return int24(tick) + (_MIN_TICK - 1);
        }
    }

    function mint(PoolKey calldata key, SimpleModifyLiquidityParams calldata params)
        external
        payable
        nonReentrant
        returns (uint256 tokenId)
    {
        unchecked {
            tokenId = nextTokenId++;
        }
        SubPositions storage subPositions = _subPositions[tokenId];
        subPositions.tree.insert(_tickToTreeKey(params.tickLower));
        subPositions.lastTick = _tickToTreeKey(params.tickUpper);

        SimpleModifyLiquidityParams[] memory paramsArray = new SimpleModifyLiquidityParams[](1);
        paramsArray[0] = params;
        POOL_MANAGER.unlock(abi.encode(msg.sender, address(0), key, bytes32(tokenId), params));

        _safeMint(msg.sender, tokenId);
    }

    function _settle(address owner, address payable recipient, Currency currency, int128 amount) private {
        if (amount < 0) {
            uint256 debt;
            unchecked {
                debt = -int256(amount);
            }
            if (currency.isAddressZero()) {
                POOL_MANAGER.settle{value: debt}();
            } else {
                POOL_MANAGER.sync(currency);
                currency.safeTransferFrom(owner, address(POOL_MANAGER), debt);
                POOL_MANAGER.settle();
            }
        } else {
            uint256 credit = uint256(int256(amount));
            POOL_MANAGER.take(currency, recipient, credit);
        }
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(POOL_MANAGER));
        (
            address owner,
            address payable recipient,
            PoolKey memory key,
            bytes32 salt,
            SimpleModifyLiquidityParams[] memory params
        ) = abi.decode(data, (address, address payable, PoolKey, bytes32, SimpleModifyLiquidityParams[]));

        BalanceDelta delta;
        ModifyLiquidityParams memory managerParams;
        managerParams.salt = salt;
        for (uint256 i; i < params.length; i++) {
            SimpleModifyLiquidityParams memory simpleParams = params[i];
            managerParams.tickLower = simpleParams.tickLower;
            managerParams.tickUpper = simpleParams.tickUpper;
            managerParams.liquidityDelta = simpleParams.liquidityDelta;
            (BalanceDelta callerDelta,) = POOL_MANAGER.modifyLiquidity(key, managerParams, ""); // TODO: hookData
            delta += callerDelta;
        }

        _settle(owner, recipient, key.currency0, delta.amount0());
        _settle(owner, recipient, key.currency1, delta.amount1());

        return "";
    }

    function getTicks(uint256 tokenId) external view returns (int24[] memory) {
        SubPositions storage subPositions = _subPositions[tokenId];
        uint24 lastTick = subPositions.lastTick;

        // allocate an extra word to store the indirection offset for the return
        assembly ("memory-safe") {
            mstore(0x40, add(0x20, mload(0x40)))
        }

        // walk the tree
        uint256[] memory result = subPositions.tree.values();

        // return
        assembly ("memory-safe") {
            // increase the length of `result` to store `lastTick`
            let len := mload(result)
            len := add(0x01, len)
            mstore(result, len)
            // insert `lastTick` at the end of the array
            len := shl(0x05, len)
            mstore(add(len, result), sub(lastTick, 887273))
            // we don't bother to increase the free memory pointer because this
            // block does not return to Solidity

            // format each tree key as a tick
            for {
                let i := add(0x20, result)
                let end := add(len, i)
            } xor(i, end) { i := add(0x20, i) } {
                // tick conversion
                mstore(i, sub(mload(i), 887273))
            }

            // return
            result := sub(result, 0x20)
            mstore(result, 0x20)
            return(result, add(0x40, len))
        }
    }
}
