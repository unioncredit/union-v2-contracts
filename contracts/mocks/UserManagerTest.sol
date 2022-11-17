//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../user/UserManagerERC20.sol";

contract UserManagerTest is UserManagerERC20 {
    function withdrawRewards2() external whenNotPaused nonReentrant {
        comptroller.withdrawRewards(msg.sender, stakingToken);
        comptroller.withdrawRewards(msg.sender, stakingToken);
    }
}
