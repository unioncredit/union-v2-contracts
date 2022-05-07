pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__updateTrust is TestWrapper {
    uint256 public trustAmount = 10 ether;

    function initStakers() internal {
        vm.startPrank(MEMBER_1);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(MEMBER_2);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(MEMBER_3);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();
    }

    function registerMember(address newMember) internal {
        vm.startPrank(MEMBER_1);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        vm.startPrank(MEMBER_2);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        vm.startPrank(MEMBER_3);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        uint256 memberFee = userManager.newMemberFee();
        unionToken.approve(address(userManager), memberFee);
        userManager.registerMember(newMember);
    }

    function testUpdateTrustRegisterMember() public {
        assert(!userManager.checkIsMember(MEMBER_4));
        initStakers();
        registerMember(MEMBER_4);
        assert(userManager.checkIsMember(MEMBER_4));
    }

    function testUpdateTrustGetCreditLimit() public {
        registerMember(MEMBER_4);
        uint256 creditLimit = userManager.getCreditLimit(MEMBER_4);
        assertEq(creditLimit, 0);
        // stakers stake to underwrite credit line
        initStakers();
        uint256 newCreditLimit = userManager.getCreditLimit(MEMBER_4);
        assertEq(newCreditLimit, trustAmount * 3);
    }
}
