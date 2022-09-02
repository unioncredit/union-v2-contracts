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

    function testGetFrozenInfo() public {
        uint96 lockAmount = 10;
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);
        uint256 blockNumberBefore = block.number;

        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        vm.roll(block.number + 10);
        uint256 blockNumberAfter = block.number;
        (uint256 totalFrozen, uint256 frozenCoinAge) = userManager.getFrozenInfo(address(this), block.number + 1);
        uint256 diff = blockNumberAfter - blockNumberBefore;

        assertEq(totalFrozen, lockAmount);
        assertEq(frozenCoinAge, lockAmount * diff);
    }

    function testGetFrozenInfoPastBlocks(uint96 lockAmount) public {
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        vm.assume(lockAmount <= creditLimit);

        vm.startPrank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        vm.roll(block.number + 10);
        (uint256 totalFrozen, uint256 frozenCoinAge) = userManager.getFrozenInfo(address(this), 1);

        assertEq(totalFrozen, lockAmount);
        assertEq(frozenCoinAge, lockAmount);
    }
}
