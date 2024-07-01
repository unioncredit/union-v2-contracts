pragma solidity ^0.8.0;
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestGetStakeInfo is TestUserManagerBase {
    using SafeCastUpgradeable for uint256;
    uint96 stakeAmount = (100 * UNIT).toUint96();
    uint96 lockAmount = (1 * UNIT).toUint96();

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
        uint startTimestamp = block.timestamp;
        uint overdueTime = 1;
        vm.prank(address(userManager.uToken()));
        skip(1); //block number 1
        uint lockedTimestamp = block.timestamp;
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueTime(overdueTime);
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 3
        skip(4); //block number 4
        uint endTimestamp = block.timestamp;
        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        uint256 expectStakedCoinAge = stakeAmount * (endTimestamp - startTimestamp);
        uint256 expectLockedCoinAge = lockAmount * (endTimestamp - lockedTimestamp);
        uint256 expectFrozenCoinAge = lockAmount * (endTimestamp - startTimestamp - overdueTime - 1);
        uint256 expectStaked = (expectStakedCoinAge - expectFrozenCoinAge) / (endTimestamp - startTimestamp);
        uint256 expectLocked = (expectLockedCoinAge - expectFrozenCoinAge) / (endTimestamp - startTimestamp);
        assertEq(effectiveStaked, expectStaked);
        assertEq(effectiveLocked, expectLocked);
    }

    //last operate stake or unstake
    function testGetStakeInfo2() public {
        skip(1); //block number 1
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueTime(1); //OverdueBlocks = 1
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 3
        skip(4); //block number 4
        userManager.unstake(stakeAmount / 2); //The reward is withdrawn, and the coinage is cleared to 0
        skip(5); //block number 5

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
        uint startTimestamp = block.timestamp;
        uint overdueTime = 2;
        skip(1); //block number 1
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueTime(overdueTime); //
        uTokenMock.setLastRepay(2); //lastRepay = 2,overdueBlockNumber = lastRepay + OverdueBlocks = 4
        skip(3); //block number 3
        vm.prank(address(userManager.uToken()));
        uint lockedTimestamp = block.timestamp;
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        skip(5); //block number 5
        uint endTimestamp = block.timestamp;
        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        uint256 expectStakedCoinAge = stakeAmount * (endTimestamp - startTimestamp);
        uint256 expectLockedCoinAge = lockAmount *
            (lockedTimestamp - startTimestamp - 1) +
            (lockAmount + lockAmount) *
            (endTimestamp - lockedTimestamp); //The lockedcoinage is updated on the block no 3
        uint256 expectFrozenCoinAge = (lockAmount + lockAmount) * (endTimestamp - startTimestamp - overdueTime - 1);
        uint256 expectStaked = (expectStakedCoinAge - expectFrozenCoinAge) / (endTimestamp - startTimestamp);
        uint256 expectLocked = (expectLockedCoinAge - expectFrozenCoinAge) / (endTimestamp - startTimestamp);
        assertEq(effectiveStaked, expectStaked);
        assertEq(effectiveLocked, expectLocked);
    }
}
