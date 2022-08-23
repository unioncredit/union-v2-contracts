//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IComptroller} from "../interfaces/IComptroller.sol";

contract ComptrollerMock is IComptroller {
    function getRewardsMultiplier(address, address) external view override returns (uint256) {
        return 0;
    }

    function withdrawRewards(address, address) external override returns (uint256) {
        return 0;
    }

    function updateTotalStaked(address, uint256) external override returns (bool) {
        return false;
    }

    function calculateRewardsByBlocks(
        address,
        address,
        uint256
    ) external view override returns (uint256) {
        return 0;
    }

    function calculateRewards(address account, address token) external view override returns (uint256) {
        return 0;
    }
}
