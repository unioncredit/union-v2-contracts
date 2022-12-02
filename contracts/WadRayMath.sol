//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title WadRayMath library
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits precision)
 *      and rays (decimals with 27 digits)
 */
library WadRayMath {
    uint256 internal constant WAD = 1e18;

    uint256 internal constant halfWAD = WAD / 2;

    error MultiplicationOverflow();
    error DivisionByZero();

    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }

        if (a > (type(uint256).max - halfWAD) / b) revert MultiplicationOverflow();

        return (halfWAD + a * b) / WAD;
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        uint256 halfB = b / 2;

        if (a > (type(uint256).max - halfB) / WAD) revert MultiplicationOverflow();

        return (a * WAD + halfB) / b;
    }
}
