//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface AMarket3 {
    function claimAllRewards(address[] calldata assets, address to) external returns (uint256);

    function getRewardsList() external view returns (address[] memory);
}
