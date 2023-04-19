//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IComptroller} from "../interfaces/IComptroller.sol";
import {IUserManager} from "../interfaces/IUserManager.sol";

contract ComptrollerMock is IComptroller {
    address public userManager;

    function setHalfDecayPoint(uint256) external {}

    function inflationPerSecond(uint256) external pure returns (uint256) {}

    function getRewardsMultiplier(address, address) external pure override returns (uint256) {
        return 0;
    }

    function withdrawRewards(address account, address) external override returns (uint256) {
        if (userManager != address(0)) {
            IUserManager(userManager).onWithdrawRewards(account);
        }
        return 0;
    }

    function accrueRewards(address account, address) external override {
        if (userManager != address(0)) {
            IUserManager(userManager).onWithdrawRewards(account);
        }
    }

    function updateTotalStaked(address, uint256) external pure override returns (bool) {
        return false;
    }

    function calculateRewards(address, address) external pure override returns (uint256) {
        return 0;
    }

    function setUserManager(address _userManager) external {
        userManager = _userManager;
    }
}
