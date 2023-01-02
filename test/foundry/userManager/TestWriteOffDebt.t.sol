pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestWriteOffDebt is TestUserManagerBase {
    address staker = MEMBER;
    address borrower = ACCOUNT;

    function setUp() public override {
        super.setUp();
        vm.startPrank(staker);
        userManager.stake(100 ether);
        userManager.updateTrust(borrower, 100 ether);
        vm.stopPrank();
        vm.mockCall(
            address(uTokenMock),
            abi.encodeWithSelector(UToken.checkIsOverdue.selector, borrower),
            abi.encode(true)
        );
    }

    function testCannotWriteOffDebtAmountZero() public {
        vm.expectRevert(UserManager.AmountZero.selector);
        userManager.debtWriteOff(staker, borrower, 0);
    }

    function testCannotWriteOffDebtNoAuth(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(address(3));
        vm.roll(1);
        vm.expectRevert(UserManager.AuthFailed.selector);
        userManager.debtWriteOff(staker, borrower, amount);
    }

    function testCannotVoucherNotFound(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(address(3));
        vm.expectRevert(UserManager.VoucherNotFound.selector);
        userManager.debtWriteOff(address(3), borrower, amount);
    }

    function testCannotWriteOffDebtExceedsLocked(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(staker);
        vm.expectRevert(UserManager.ExceedsLocked.selector);
        userManager.debtWriteOff(staker, borrower, amount);
    }

    function testDebtWriteOffAll() public {
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, 100 ether, true);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, 100 ether);
        uint256 stakeAmount = userManager.getStakerBalance(staker);
        assertEq(stakeAmount, 0);

        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, false);
    }

    function testDebtWriteOffPart(uint96 writeOffAmount, uint96 amount) public {
        vm.assume(amount > 2 && amount < 100 ether);
        vm.assume(writeOffAmount > 1 && writeOffAmount < amount);
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, amount, true);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, writeOffAmount);
        uint256 stakeAmount = userManager.getStakerBalance(staker);

        assertEq(stakeAmount, 100 ether - writeOffAmount);
        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, true);
    }

    function testDebtWriteOffPartWithFrozen(uint96 writeOffAmount, uint96 amount) public {
        vm.assume(amount > 2 && amount < 100 ether);
        vm.assume(writeOffAmount > 1 && writeOffAmount < amount);

        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, amount, true);

        uint256 totalFrozen = userManager.totalFrozen();
        uint256 memberFrozen = userManager.memberFrozen(staker);
        assertEq(totalFrozen, 0);
        assertEq(memberFrozen, 0);

        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, writeOffAmount);
        uint256 stakeAmount = userManager.getStakerBalance(staker);
        assertEq(stakeAmount, 100 ether - writeOffAmount);

        assertEq(userManager.totalFrozen(), 0);
        assertEq(userManager.memberFrozen(staker), 0);

        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, true);
    }

    function testDebtWriteOffPartWithoutFrozen(uint96 writeOffAmount, uint96 amount) public {
        vm.assume(amount > 2 && amount < 100 ether);
        vm.assume(writeOffAmount > 1 && writeOffAmount < amount);

        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, amount, true);
        uTokenMock.setOverdueBlocks(0);
        uTokenMock.setLastRepay(block.number);

        vm.roll(2);
        address[] memory stakers = new address[](1);
        stakers[0] = staker;
        userManager.batchUpdateFrozenInfo(stakers);

        uint256 totalFrozen = userManager.totalFrozen();
        uint256 memberFrozen = userManager.memberFrozen(staker);
        assertEq(totalFrozen, amount);
        assertEq(memberFrozen, amount);

        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, writeOffAmount);
        uint256 stakeAmount = userManager.getStakerBalance(staker);
        assertEq(stakeAmount, 100 ether - writeOffAmount);

        assertEq(userManager.totalFrozen(), totalFrozen - writeOffAmount);
        assertEq(userManager.memberFrozen(staker), memberFrozen - writeOffAmount);

        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, true);
    }
}
