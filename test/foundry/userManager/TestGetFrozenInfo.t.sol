pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestGetFrozenInfo is TestUserManagerBase {
    uint96 stakeAmount = 100 ether;

    function setUp() public override {
        super.setUp();
        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();

        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    function testGetStakeInfo() public {
        uint96 lockAmount = 10 ether;
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);
        vm.roll(block.number + 10);
        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();
        vm.roll(block.number + 10);
        (uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this), 0);
        assertEq(effectiveStaked, stakeAmount);
        assertEq(effectiveLocked, lockAmount / 2);
    }

    function testGetStakeInfoPastBlocks(uint96 lockAmount) public {
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);

        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueBlocks(0);
        uTokenMock.setLastRepay(block.number);
        vm.stopPrank();

        vm.roll(block.number + 10);
        (, uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this), block.number + 1);

        assertEq(effectiveLocked, 0);
    }
}
