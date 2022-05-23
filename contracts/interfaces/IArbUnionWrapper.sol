// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IArbUnionWrapper {
    function router() external returns (address);

    function balanceOf(address) external returns (uint256);

    function wrap(uint256) external returns (bool);

    function unwrap(uint256) external returns (bool);
}
