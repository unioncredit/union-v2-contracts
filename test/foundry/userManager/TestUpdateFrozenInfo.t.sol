pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestUpdateFrozenInfo is TestUserManagerBase {
    uint96 stakeAmount = 100 ether;
    uint96 lockAmount = 10;

    function setUp() public override {
        super.setUp();

        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();

        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    function testUpdateFrozenInfo() public {
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.roll(block.number + 10);

        vm.prank(address(userManager.comptroller()));
        userManager.updateFrozenInfo(address(this), block.number + 1);
        (uint256 totalFrozen, ) = userManager.getFrozenInfo(address(this), block.number + 1);

        assertEq(totalFrozen, lockAmount);
        assertEq(userManager.memberFrozen(address(this)), totalFrozen);
        assertEq(userManager.totalFrozen(), totalFrozen);
    }
}
