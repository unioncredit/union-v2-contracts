//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title ScaledDecimalBase
 * @dev For easy access to the utility functions of scaling decimals
 */
abstract contract ScaledDecimalBase {
    function decimalScaling(uint256 amount, uint8 decimal) internal pure returns (uint256) {
        if (decimal > 18) {
            uint8 diff = decimal - 18;
            return amount / 10 ** diff;
        } else {
            uint8 diff = 18 - decimal;
            return amount * 10 ** diff;
        }
    }

    function decimalReducing(uint256 actualAmount, uint8 decimal) internal pure returns (uint256) {
        if (decimal > 18) {
            uint8 diff = decimal - 18;
            return actualAmount * 10 ** diff;
        } else {
            uint8 diff = 18 - decimal;
            return actualAmount / 10 ** diff;
        }
    }

    function decimalReducing(uint256 actualAmount, uint8 decimal, bool roundUp) internal pure returns (uint256) {
        if (decimal > 18) {
            uint8 diff = decimal - 18;
            return actualAmount * 10 ** diff;
        } else {
            uint8 diff = 18 - decimal;
            uint256 rounding = roundUp ? 10 ** diff - 1 : 0;
            return (actualAmount + rounding) / 10 ** diff;
        }
    }
}
