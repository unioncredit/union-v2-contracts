//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * @dev Authors: Balance -> Union
 * @dev Original code here: github.com/balancer-labs/balancer-v2-monorepo/blob/master/pkg/interfaces/contracts/solidity-utils/helpers/BalancerErrors.sol
 * @dev Modified BAL#000 -> UNION#000
 */
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}

function _revert(uint256 errorCode) pure {
    uint256 prefix = uint256(0x554e494f4e);

    assembly {
        let units := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        let formattedPrefix := shl(24, add(0x23, shl(8, prefix)))
        let revertReason := shl(184, add(formattedPrefix, add(add(units, shl(8, tenths)), shl(16, hundreds))))

        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        mstore(0x24, 9)
        mstore(0x44, revertReason)

        revert(0, 100)
    }
}

// prettier-ignore
library Errors {
    // UserManager
    uint256 public constant SELF_VOUCHING         = 100;
    uint256 public constant TRUST_LT_LOCKED       = 101;
    uint256 public constant ALREADY_MEMBER        = 102;
    uint256 public constant NOT_ENOUGH_STAKERS    = 103;
    uint256 public constant STAKE_LIMIT           = 104;
    uint256 public constant ASSET_DEPOSIT_FAILED  = 105;
    uint256 public constant ASSET_WITHDRAW_FAILED = 106;
    uint256 public constant LOCK_STAKE_NOT_ZERO   = 107;
    uint256 public constant EXCEEDS_LOCKED        = 107;
    uint256 public constant LOCKED_REMAINING      = 108;
    uint256 public constant VOUCHER_NOT_FOUND     = 109;

    // UToken
    uint256 public constant NOT_OVERDUE           = 200;

    // Lib
    uint256 public constant UNAUTHORIZED          = 400;
    uint256 public constant AMOUNT_ZERO           = 401;
    uint256 public constant INSUFFICIENT_BALANCE  = 402;
}
