pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__cancelVouch is TestWrapper {
    address public newMember = address(777);

    function setUp() public override {
        super.setUp();
        initStakers();
    }

    function testCancelVouch() public {
        vm.prank(MEMBER_1);
        userManager.updateTrust(newMember, 100);
        vm.prank(MEMBER_2);
        userManager.updateTrust(newMember, 100);

        (address staker0, , ) = userManager.vouchers(newMember, 0);
        assertEq(staker0, MEMBER_1);

        (address staker1, , ) = userManager.vouchers(newMember, 1);
        assertEq(staker1, MEMBER_2);

        vm.prank(MEMBER_1);
        userManager.cancelVouch(MEMBER_1, newMember);
        (address staker2, , ) = userManager.vouchers(newMember, 0);
        assertEq(staker2, MEMBER_2);
    }
}
