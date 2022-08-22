pragma solidity ^0.8.0;
import "union-v1.5-contracts/errors.sol";
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";

contract TestRegister is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotRegisterWhenIsMember() public {
        vm.expectRevert("UNION#102");
        userManager.registerMember(MEMBER);
    }

    function testCannotRegisterNotEnoughStakers() public {
        vm.expectRevert("UNION#103");
        userManager.registerMember(ACCOUNT);
    }

    function testCannotReigsterWithZeroVouchStakers() public {
        vm.prank(ADMIN);
        userManager.setEffectiveCount(1);
        vm.prank(MEMBER);
        userManager.updateTrust(ACCOUNT, 1 ether);
        vm.expectRevert("UNION#103");
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
