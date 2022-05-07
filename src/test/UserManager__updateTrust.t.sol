pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__updateTrust is TestWrapper {
    uint256 public trustAmount = 10 ether;

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
        registerMember(MEMBER_4);
        assert(userManager.checkIsMember(MEMBER_4));
    }
}
