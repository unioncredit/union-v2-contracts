pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestGetStakeInfo is TestUserManagerBase {
    uint96 stakeAmount = 100 ether;
    uint96 lockAmount = 1 ether;

    function setUp() public override {
        super.setUp();
        comptrollerMock.setUserManager(address(userManager));

        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();

        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    //last operate repay
    function testGetStakeInfo() public {
        vm.prank(address(userManager.uToken()));
        vm.roll(1); //block number 1
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueBlocks(1); //OverdueBlocks = 1
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 3
        vm.roll(4); //block number 4

        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        uint256 expectStakedCoinAge = stakeAmount * (4 - 1);
        uint256 expectLockedCoinAge = lockAmount * (4 - 1);
        uint256 expectFrozenCoinAge = lockAmount * (4 - 3);
        uint256 expectStaked = (expectStakedCoinAge - expectFrozenCoinAge) / 3;
        uint256 expectLocked = (expectLockedCoinAge - expectFrozenCoinAge) / 3;
        assertEq(effectiveStaked, expectStaked);
        assertEq(effectiveLocked, expectLocked);
    }

    //last operate stake or unstake
    function testGetStakeInfo2() public {
        vm.roll(1); //block number 1
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueBlocks(1); //OverdueBlocks = 1
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 3
        vm.roll(4); //block number 4
        userManager.unstake(stakeAmount / 2); //The reward is withdrawn, and the coinage is cleared to 0
        vm.roll(5); //block number 5

        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        //coinage calc from block number 4
        uint256 expectStakedCoinAge = (stakeAmount / 2) * (5 - 4);
        uint256 expectLockedCoinAge = lockAmount * (5 - 4);
        uint256 expectFrozenCoinAge = lockAmount * (5 - 4);
        uint256 expectStaked = (expectStakedCoinAge - expectFrozenCoinAge) / (5 - 4);
        uint256 expectLocked = (expectLockedCoinAge - expectFrozenCoinAge) / (5 - 4);
        assertEq(effectiveStaked, expectStaked);
        assertEq(effectiveLocked, expectLocked);
    }

    //last operate update locked
    function testGetStakeInfo3() public {
        vm.roll(1); //block number 1
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueBlocks(2); //OverdueBlocks = 2
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 4
        vm.roll(3); //block number 3
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.roll(5); //block number 5

        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        uint256 expectStakedCoinAge = stakeAmount * (5 - 1);
        uint256 expectLockedCoinAge = lockAmount * (3 - 1) + (lockAmount + lockAmount) * (5 - 3); //The lockedcoinage is updated on the block no 3
        uint256 expectFrozenCoinAge = (lockAmount + lockAmount) * (5 - 4);
        uint256 expectStaked = (expectStakedCoinAge - expectFrozenCoinAge) / (5 - 1);
        uint256 expectLocked = (expectLockedCoinAge - expectFrozenCoinAge) / (5 - 1);
        assertEq(effectiveStaked, expectStaked);
        assertEq(effectiveLocked, expectLocked);
    }
}
