pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestGetFrozenInfo is TestUserManagerBase {
    using SafeCastUpgradeable for uint256;
    uint96 stakeAmount = (100 * UNIT).toUint96();

    function setUp() public override {
        super.setUp();
        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();

        comptrollerMock.setUserManager(address(userManager));

        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    function testGetStakeInfo() public {
        uint96 lockAmount = (10 * UNIT).toUint96();
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        uint256 globalStakedBefore = userManager.globalTotalStaked();
        uint256 totalFrozenBefore = userManager.totalFrozen();
        uint256 startTimestamp = block.timestamp;
        vm.assume(lockAmount <= creditLimit);
        skip(11); // 10 more blocks
        uint256 lockedTimestamp = block.timestamp;
        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();
        skip(21); // another 10 blocks
        uint256 endTimestamp = block.timestamp;
        (, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));
        assertEq(effectiveStaked, stakeAmount);
        assertEq(effectiveLocked, (lockAmount * (endTimestamp - lockedTimestamp)) / (endTimestamp - startTimestamp));
        uint256 globalStakedAfter = userManager.globalTotalStaked();
        uint256 totalFrozenAfter = userManager.totalFrozen();
        assertEq(globalStakedBefore - globalStakedAfter, totalFrozenAfter - totalFrozenBefore);
    }
}
