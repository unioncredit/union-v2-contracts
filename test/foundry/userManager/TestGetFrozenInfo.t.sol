pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";

contract TestGetFrozenInfo is TestUserManagerBase {
    address[] public MEMBERS = [address(10), address(11), address(12)];
    uint96 stakeAmount = 100 ether;

    function setUp() public override {
        super.setUp();
        for (uint256 i = 0; i < MEMBERS.length; i++) {
            vm.prank(ADMIN);
            userManager.addMember(MEMBERS[i]);
            daiMock.mint(MEMBERS[i], stakeAmount);

            vm.startPrank(MEMBERS[i]);
            daiMock.approve(address(userManager), type(uint256).max);
            userManager.stake(stakeAmount);
            userManager.updateTrust(ACCOUNT, stakeAmount);
            vm.stopPrank();
        }
    }

    function testGetFrozenInfo(uint96 lockAmount) public {
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);
        vm.startPrank(address(userManager.uToken()));
        uint256 blockNumberBefore = block.number;
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        vm.roll(block.number + 10);
        uint256 blockNumberAfter = block.number;
        (uint256 totalFrozen, uint256 frozenCoinage) = userManager.getFrozenInfo(ACCOUNT, block.number + 1);
        uint256 diff = blockNumberAfter - blockNumberBefore;

        assertEq(totalFrozen, lockAmount);
        assertEq(frozenCoinage, lockAmount * diff);
    }

    function testGetFrozenInfoPastBlocks(uint96 lockAmount) public {
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);
        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        vm.roll(block.number + 10);
        (uint256 totalFrozen, uint256 frozenCoinage) = userManager.getFrozenInfo(ACCOUNT, 1);

        assertEq(totalFrozen, lockAmount);
        assertEq(frozenCoinage, lockAmount);
    }
}
