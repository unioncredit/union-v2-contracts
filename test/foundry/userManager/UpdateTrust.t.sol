pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";

contract TestUpdateTrust is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
        vm.prank(MEMBER);
        userManager.stake(100 ether);
    }

    function testGetCreditLimit(uint96 trustAmount) public {
        vm.assume(trustAmount <= 100 ether);
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, trustAmount);
        vm.stopPrank();
        uint256 newCreditLimit = userManager.getCreditLimit(ACCOUNT);
        assertEq(newCreditLimit, trustAmount);
    }

    function testCreatesVouch(uint96 trustAmount) public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, trustAmount);
        (, uint256 vouchIndex) = userManager.voucherIndexes(ACCOUNT, address(this));
        (address staker, uint96 amount, uint96 outstanding, ) = userManager.vouchers(ACCOUNT, vouchIndex);
        vm.stopPrank();
        assertEq(staker, MEMBER);
        assertEq(amount, trustAmount);
        assertEq(outstanding, 0);
    }

    function testExistingVouch(uint96 amount0, uint96 amount1) public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, amount0);
        (, uint256 vouchIndex) = userManager.voucherIndexes(ACCOUNT, MEMBER);
        (, uint256 amountBefore, , ) = userManager.vouchers(ACCOUNT, vouchIndex);
        assertEq(amountBefore, amount0);
        userManager.updateTrust(ACCOUNT, amount1);
        (, uint256 amountAfter, , ) = userManager.vouchers(ACCOUNT, vouchIndex);
        assertEq(amountAfter, amount1);
        vm.stopPrank();
    }

    function testSavesVouchIndex() public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, 100);
        (bool isSet, ) = userManager.voucherIndexes(ACCOUNT, MEMBER);
        assert(isSet);
        vm.stopPrank();
    }

    function testCannotOnZeroAddress() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(UserManager.AddressZero.selector);
        userManager.updateTrust(address(0), 123);
        vm.stopPrank();
    }

    function testCannotOnSelf() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(UserManager.ErrorSelfVouching.selector);
        userManager.updateTrust(MEMBER, 123);
        vm.stopPrank();
    }

    function testCannotNonMember() public {
        vm.startPrank(address(999));
        vm.expectRevert(UserManager.AuthFailed.selector);
        userManager.updateTrust(address(1234), 100);
    }

    function testCannotLessThanOutstanding() public {
        // TODO:
    }
}