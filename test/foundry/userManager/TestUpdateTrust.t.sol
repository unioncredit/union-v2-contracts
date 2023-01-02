pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

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

    function testCannotCancelNotStakerOrBorrower() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(UserManager.AuthFailed.selector);
        userManager.cancelVouch(address(3), address(4));
        vm.stopPrank();
    }

    function testCancelNoVouch() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(UserManager.VoucherNotFound.selector);
        userManager.cancelVouch(MEMBER, ACCOUNT);
        vm.stopPrank();
    }

    function testCancelStakeNonZero() public {
        vm.prank(MEMBER);
        userManager.updateTrust(ACCOUNT, 100);
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, 100, true);
        vm.expectRevert(UserManager.LockedStakeNonZero.selector);
        vm.prank(MEMBER);
        userManager.cancelVouch(MEMBER, ACCOUNT);
    }

    function testCancelVouch(uint96 amount) public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, amount);
        (, uint256 vouchIndex) = userManager.voucherIndexes(ACCOUNT, MEMBER);
        (, uint256 vouchAmount, , ) = userManager.vouchers(ACCOUNT, vouchIndex);
        assertEq(vouchAmount, amount);
        userManager.cancelVouch(MEMBER, ACCOUNT);
        (bool isSet, ) = userManager.voucherIndexes(ACCOUNT, MEMBER);
        assert(!isSet);
        vm.stopPrank();
    }

    function testSavesVouchIndex() public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(ACCOUNT, 100);
        (bool isSet, ) = userManager.voucherIndexes(ACCOUNT, MEMBER);
        assert(isSet);
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

    function testCannotOverdue() public {
        vm.startPrank(MEMBER);
        userManager.updateTrust(address(123), 100);
        vm.expectRevert(UserManager.VouchWhenOverdue.selector);
        vm.mockCall(
            address(uTokenMock),
            abi.encodeWithSelector(UToken.checkIsOverdue.selector, MEMBER),
            abi.encode(true)
        );
        userManager.updateTrust(address(1234), 100);

        // can call update trust on existing users
        userManager.updateTrust(address(123), 0);
    }

    function testCannotVouchForMoreThanMaxLimit() public {
        vm.prank(ADMIN);
        userManager.setMaxVouchees(2);

        vm.startPrank(MEMBER);
        userManager.updateTrust(address(123), 10 ether);
        userManager.updateTrust(address(1234), 10 ether);
        vm.expectRevert(UserManager.MaxVouchees.selector);
        userManager.updateTrust(address(12345), 10 ether);
        vm.stopPrank();
    }

    function testCannotRecieveVouchesForMoreThanMaxLimit() public {
        address member0 = address(123);
        address member1 = address(456);

        vm.startPrank(ADMIN);
        userManager.addMember(member0);
        userManager.addMember(member1);
        userManager.setMaxVouchers(1);
        vm.stopPrank();

        address vouchTo = address(789);

        vm.prank(member0);
        userManager.updateTrust(vouchTo, 10 ether);

        vm.prank(member1);
        vm.expectRevert(UserManager.MaxVouchers.selector);
        userManager.updateTrust(vouchTo, 10 ether);
    }
}
