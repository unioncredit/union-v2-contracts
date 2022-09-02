pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestRegister is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotRegisterWhenIsMember() public {
        vm.expectRevert(UserManager.NoExistingMember.selector);
        userManager.registerMember(MEMBER);
    }

    function testCannotRegisterNotEnoughStakers() public {
        vm.expectRevert(UserManager.NotEnoughStakers.selector);
        userManager.registerMember(ACCOUNT);
    }

    function testCannotReigsterWithZeroVouchStakers() public {
        vm.prank(ADMIN);
        userManager.setEffectiveCount(1);
        vm.prank(MEMBER);
        userManager.updateTrust(ACCOUNT, 1 ether);
        vm.expectRevert(UserManager.NotEnoughStakers.selector);
        userManager.registerMember(ACCOUNT);
    }

    function testRegister() public {
        vm.startPrank(ADMIN);
        uint256 newMemberFee = userManager.newMemberFee();
        unionTokenMock.mint(MEMBER, newMemberFee);
        userManager.setEffectiveCount(1);
        vm.stopPrank();
        vm.startPrank(MEMBER);
        unionTokenMock.approve(address(userManager), newMemberFee);
        userManager.stake(10 ether);
        userManager.updateTrust(ACCOUNT, 1 ether);
        userManager.registerMember(ACCOUNT);
        vm.stopPrank();
    }
}
