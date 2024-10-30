pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestBorrowRepay is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function testRepayBorrow() public {
        uint256 borrowAmount = svm.createUint256("borrowAmount");
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        skip(block.timestamp + 1);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        daiMock.approve(address(uToken), repayAmount);
        daiMock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);

        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowWhenOverdue() public {
        uint256 borrowAmount = svm.createUint256("borrowAmount");
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(ALICE, borrowAmount);

        // fast forward to overdue block
        skip(block.timestamp + OVERDUE_TIME + 1);

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

    function testRepayBorrowOnBehalf() public {
        uint256 borrowAmount = svm.createUint256("borrowAmount");
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

    function testRepayBorrowOnBehalfAll() public {
        uint256 borrowAmount = svm.createUint256("borrowAmount");
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

    function testDebtWriteOff() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount > 0);

        vm.prank(ALICE);
        uToken.borrow(ALICE, MIN_BORROW);
        uint256 borrowedBefore = uToken.getBorrowed(ALICE);

        vm.prank(address(userManagerMock));
        uToken.debtWriteOff(ALICE, borrowedBefore);
        uint256 borrowedAfter = uToken.getBorrowed(ALICE);
        assertEq(borrowedAfter, 0);
    }
}
