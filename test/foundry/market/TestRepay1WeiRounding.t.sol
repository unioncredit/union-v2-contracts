// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestUTokenBase} from "../uToken/TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

/**
 * @title Test for 1 Wei Rounding Issue
 * @notice Tests the fix for the bug where 1 wei remains locked after full repayment
 * @dev Uses actual UToken contract to test the complete borrow/repay flow
 */
contract TestRepay1WeiRounding is TestUTokenBase {
    
    function setUp() public override {
        super.setUp();
        
        // Give ALICE tokens for repayment
        erc20Mock.mint(ALICE, 1000 * UNIT);
        
        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @notice Main test: full repayment should clear all locked funds
     */
    function testFullRepaymentClearsAllLocked() public {
        if (tokenDecimals >= 18) return; // Only test for tokens with rounding
        
        vm.startPrank(ALICE);
        
        uint256 borrowAmount = 100 * UNIT;
        uToken.borrow(ALICE, borrowAmount);
        
        uint256 lockedAfterBorrow = userManagerMock.getTotalLockedStake(ALICE);
        assertGt(lockedAfterBorrow, 0, "Should have locked funds after borrow");
        
        // Fully repay
        uint256 totalOwed = uToken.borrowBalanceView(ALICE);
        uToken.repayBorrow(ALICE, totalOwed + 1);
        
        uint256 borrowedAfter = uToken.getBorrowed(ALICE);
        uint256 lockedAfter = userManagerMock.getTotalLockedStake(ALICE);
        
        vm.stopPrank();
        
        assertEq(borrowedAfter, 0, "Borrowed must be 0 after full repayment");
        assertEq(lockedAfter, 0, "Locked must be 0 after full repayment (FIX APPLIED)");
    }
    
    /**
     * @notice Test with minimum borrow amount
     */
    function testMinimumBorrowFullRepay() public {
        if (tokenDecimals >= 18) return;
        
        vm.startPrank(ALICE);
        
        uint256 minBorrow = uToken.minBorrow();
        uToken.borrow(ALICE, minBorrow);
        
        uint256 totalOwed = uToken.borrowBalanceView(ALICE);
        uToken.repayBorrow(ALICE, totalOwed + 1);
        
        assertEq(uToken.getBorrowed(ALICE), 0, "Borrowed should be 0");
        assertEq(userManagerMock.getTotalLockedStake(ALICE), 0, "Locked should be 0");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test partial repayment doesn't clear all locks
     */
    function testPartialRepaymentKeepsLocked() public {
        if (tokenDecimals >= 18) return;
        
        vm.startPrank(ALICE);
        
        uint256 borrowAmount = 100 * UNIT;
        uToken.borrow(ALICE, borrowAmount);
        
        uint256 lockedAfterBorrow = userManagerMock.getTotalLockedStake(ALICE);
        
        // Partial repay
        uToken.repayBorrow(ALICE, borrowAmount / 2);
        
        uint256 borrowedAfterPartial = uToken.getBorrowed(ALICE);
        uint256 lockedAfterPartial = userManagerMock.getTotalLockedStake(ALICE);
        
        assertGt(borrowedAfterPartial, 0, "Should have debt after partial repay");
        assertGt(lockedAfterPartial, 0, "Should have locked after partial repay");
        assertLt(lockedAfterPartial, lockedAfterBorrow, "Locked should decrease");
        
        // Final repay
        uint256 totalOwed = uToken.borrowBalanceView(ALICE);
        uToken.repayBorrow(ALICE, totalOwed + 1);
        
        assertEq(uToken.getBorrowed(ALICE), 0, "Final borrowed should be 0");
        assertEq(userManagerMock.getTotalLockedStake(ALICE), 0, "Final locked should be 0");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Fuzz test various borrow amounts
     */
    function testFuzzFullRepaymentClearsLock(uint96 borrowAmount) public {
        if (tokenDecimals >= 18) return;
        
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount <= MAX_BORROW / 2);
        
        vm.startPrank(ALICE);
        
        uToken.borrow(ALICE, borrowAmount);
        
        uint256 totalOwed = uToken.borrowBalanceView(ALICE);
        uToken.repayBorrow(ALICE, totalOwed + UNIT);
        
        assertEq(uToken.getBorrowed(ALICE), 0, "Fuzz: Borrowed should be 0");
        assertEq(userManagerMock.getTotalLockedStake(ALICE), 0, "Fuzz: Locked should be 0");
        
        vm.stopPrank();
    }
}
