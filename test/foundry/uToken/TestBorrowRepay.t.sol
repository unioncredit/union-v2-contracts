pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestBorrowRepay is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotBorrowNonMember() public {
        userManagerMock.setIsMember(false);

        vm.expectRevert(UToken.CallerNotMember.selector);
        uToken.borrow(address(this), 1 ether);
    }

    function testBorrowFeeAndInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);
        uToken.borrow(ALICE, borrowAmount);
        vm.stopPrank();

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        // borrowed amount should only include origination fee
        uint256 fees = (ORIGINATION_FEE * borrowAmount) / 1 ether;
        assertEq(borrowed, borrowAmount + fees);

        // advance 1 more block
        vm.roll(block.number + 1);

        // borrowed amount should now include interest
        uint256 interest = ((borrowAmount + fees) * BORROW_INTEREST_PER_BLOCK) / 1 ether;

        assertEq(uToken.borrowBalanceView(ALICE), borrowed + interest);
    }

    function testRepayBorrow(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1 ether);

        vm.roll(block.number + 1);

        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);

        uint256 repayAmount = borrowed + interest;

        daiMock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowLessThanInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);
        
        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);
        // fast forward to overdue block
        vm.roll(block.number + OVERDUE_BLOCKS + 1);
        assertTrue(uToken.checkIsOverdue(ALICE));

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = interest - 1;

        daiMock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();
        //repay less than interest, overdue state does not change
        assertTrue(uToken.checkIsOverdue(ALICE));
    }

    function testRepayBorrowWhenOverdue(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        // fast forward to overdue block
        vm.roll(block.number + OVERDUE_BLOCKS + 1);

        assertTrue(uToken.checkIsOverdue(ALICE));

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        daiMock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();

        assertTrue(!uToken.checkIsOverdue(ALICE));

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowOnBehalf(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        // Alice borrows first
        vm.prank(ALICE);
        uToken.borrow(ALICE, borrowAmount);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        // Bob repay on behalf of Alice
        vm.startPrank(BOB);
        daiMock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);
        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowOnBehalfAll(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        // Alice borrows first
        vm.prank(ALICE);
        uToken.borrow(ALICE, borrowAmount);

        // Bob repay on behalf of Alice
        vm.startPrank(BOB);
        daiMock.approve(address(uToken), type(uint256).max);
        uToken.repayBorrow(ALICE, type(uint256).max);
        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testDebtWriteOff(uint256 amount) public {
        vm.assume(amount > 0);

        vm.prank(ALICE);
        uToken.borrow(ALICE, MIN_BORROW);
        uint borrowedBefore = uToken.getBorrowed(ALICE);

        vm.prank(address(userManagerMock));
        uToken.debtWriteOff(ALICE, borrowedBefore);
        uint borrowedAfter = uToken.getBorrowed(ALICE);
        assertEq(borrowedAfter, 0);
    }
}
