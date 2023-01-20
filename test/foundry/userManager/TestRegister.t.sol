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

    event LogRegisterMember(address indexed account, address indexed borrower);

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

        vm.expectEmit(true, true, true, true, address(userManager));
        emit LogRegisterMember(MEMBER, ACCOUNT);
        userManager.registerMember(ACCOUNT);
        vm.stopPrank();
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function testOptimismRegistration() public {
        vm.startPrank(ADMIN);
        uint256 newMemberFee = userManagerOp.newMemberFee();
        unionTokenMock.mint(MEMBER, newMemberFee);
        userManagerOp.setEffectiveCount(1);
        vm.stopPrank();
        vm.startPrank(MEMBER);
        unionTokenMock.approve(address(userManagerOp), newMemberFee);
        userManagerOp.stake(10 ether);
        userManagerOp.updateTrust(ACCOUNT, 1 ether);

        // Make sure the Union tokens are transferred to the comptroller
        vm.expectEmit(true, true, false, true, address(unionTokenMock));
        emit Transfer(MEMBER, address(comptrollerMock), newMemberFee);

        vm.expectEmit(true, true, true, true, address(userManagerOp));
        emit LogRegisterMember(MEMBER, ACCOUNT);
        userManagerOp.registerMember(ACCOUNT);
        vm.stopPrank();
    }
}
