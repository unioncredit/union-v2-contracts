//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface AMarket3 {
    function claimAllRewards(address[] calldata assets, address to) external returns (uint256);
}
