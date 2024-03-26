pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestBorrowRepay is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function nearlyEqual(uint256 a, uint256 b, uint256 eps) private pure returns (bool) {
        return (a >= b && a - b <= eps) || (b > a && b - a <= eps);
    }

    function testCannotBorrowNonMember() public {
        userManagerMock.setIsMember(false);

        vm.expectRevert(UToken.CallerNotMember.selector);
        uToken.borrow(address(this), 1 * UNIT);
    }

    function testBorrowFeeAndInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);
        uint256 debtCeilingBefore = uToken.getRemainingDebtCeiling();
        vm.startPrank(ALICE);
        uToken.borrow(ALICE, borrowAmount);
        vm.stopPrank();
        uint256 debtCeilingAfter = uToken.getRemainingDebtCeiling();

        nearlyEqual(
            (debtCeilingBefore - debtCeilingAfter),
            (borrowAmount + (borrowAmount * ORIGINATION_FEE) / 1e18),
            100
        );
        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        // borrowed amount should only include origination fee
        uint256 fees = (ORIGINATION_FEE * borrowAmount) / 1e18;
        assertEq(borrowed, borrowAmount + fees);
        // advance 60 seconds
        skip(block.timestamp + 60);
        // borrowed amount should now include interest
        uint256 interest = (((borrowAmount + fees) * BORROW_INTEREST_PER_BLOCK) * (60 + 1)) / 1e18;
        assertEq(uToken.borrowBalanceView(ALICE), borrowed + interest);
    }

    function testBorrowWhenNotEnough(uint256 borrowAmount) public {
        vm.assume(
            borrowAmount >= MIN_BORROW &&
                borrowAmount > UNIT &&
                borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18
        );

        vm.startPrank(ALICE);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, erc20Mock, ALICE, borrowAmount),
            abi.encode(UNIT)
        );
        uToken.borrow(ALICE, borrowAmount);
        vm.stopPrank();

        uint256 borrowed = uToken.getBorrowed(ALICE);
        uint256 realBorrowAmount = borrowAmount - UNIT;
        // borrowed amount should only include origination fee
        uint256 fees = (ORIGINATION_FEE * realBorrowAmount) / 1e18;
        assertEq(borrowed, realBorrowAmount + fees);
    }

    function testRepayBorrow(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1e18);

        skip(block.timestamp + 1);

        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);

        uint256 repayAmount = borrowed + interest + 100; //prevent dust

        erc20Mock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();
        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowLessThanInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);
        // fast forward to overdue block
        skip(block.timestamp + OVERDUE_TIME + 1);
        assertTrue(uToken.checkIsOverdue(ALICE));

        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = interest - 1;

        erc20Mock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();
        //repay less than interest, overdue state does not change
        assertTrue(uToken.checkIsOverdue(ALICE));
    }

    function testRepayBorrowWhenOverdue(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        // fast forward to overdue block
        skip(block.timestamp + OVERDUE_TIME + 1);

        assertTrue(uToken.checkIsOverdue(ALICE));

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        erc20Mock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();

        assertTrue(!uToken.checkIsOverdue(ALICE));
        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowOnBehalf(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        // Alice borrows first
        vm.prank(ALICE);
        uToken.borrow(ALICE, borrowAmount);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        // Bob repay on behalf of Alice
        vm.startPrank(BOB);
        erc20Mock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);
        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowOnBehalfAll(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        // Alice borrows first
        vm.prank(ALICE);
        uToken.borrow(ALICE, borrowAmount);

        // Bob repay on behalf of Alice
        vm.startPrank(BOB);
        erc20Mock.approve(address(uToken), type(uint96).max);
        uToken.repayBorrow(ALICE, type(uint96).max);
        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testDebtWriteOff(uint256 amount) public {
        vm.assume(amount > 0);

        vm.prank(ALICE);
        uToken.borrow(ALICE, MIN_BORROW);
        uint256 borrowedBefore = uToken.getBorrowed(ALICE);

        vm.prank(address(userManagerMock));
        uToken.debtWriteOff(ALICE, borrowedBefore);
        uint256 borrowedAfter = uToken.getBorrowed(ALICE);
        assertEq(borrowedAfter, 0);
    }

    function testRepayInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        vm.startPrank(ALICE);
        uToken.borrow(ALICE, borrowAmount);
        // fast forward a few blocks to acrue some interest
        skip(block.timestamp + 10);
        uint256 interest = uToken.calculatingInterest(ALICE);
        assert(interest > 0);

        uint256 borrowedBefore = uToken.borrowBalanceView(ALICE);
        erc20Mock.approve(address(uToken), interest);
        uToken.repayInterest(ALICE);
        uint256 borrowedAfter = uToken.borrowBalanceView(ALICE);
        assertEq(borrowedBefore - borrowedAfter, interest);

        vm.stopPrank();
    }
}
