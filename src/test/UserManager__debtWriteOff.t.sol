pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__debtWriteOff is TestWrapper {
    uint256 public borrowAmount = 10 ether;
    uint256 public repayAmount = (10 ether * 10) / 100;

    address public staker;
    address public borrower;

    uint128 public vouchAmount;
    uint128 public vouchOutstanding;

    function setUp() public override {
        super.setUp();
        staker = MEMBER_1;
        borrower = MEMBER_4;

        borrow();
        (, vouchAmount, vouchOutstanding) = getVouch();
    }

    function borrow() public {
        initStakers();
        registerMember(borrower);
        vm.startPrank(borrower);
        uToken.borrow(borrowAmount);
        vm.stopPrank();
    }

    function getVouch()
        public
        view
        returns (
            address,
            uint128,
            uint128
        )
    {
        uint256 index = userManager.voucherIndexes(borrower, staker);
        return userManager.vouchers(borrower, index - 1);
    }

    function testDebtWriteOffStakedAmount() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        uint256 balBefore = userManager.getStakerBalance(staker);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 balAfter = userManager.getStakerBalance(staker);
        assertEq(balBefore - balAfter, vouchOutstanding);
    }

    function testDebtWriteOffVouchAmount() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        (, uint128 amountBefore, ) = getVouch();
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        (, uint128 amountAfter, ) = getVouch();
        assertEq(amountBefore - vouchOutstanding, amountAfter);
    }

    function testDebtWriteOffFrozenAmount() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        uToken.updateOverdueInfo(borrower);
        uint256 frozenBefore = userManager.getTotalFrozenAmount(borrower);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 frozenAfter = userManager.getTotalFrozenAmount(borrower);
        assertEq(frozenBefore - frozenAfter, vouchOutstanding);
    }

    function testDebtWriteOffTotalFrozenAmount() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        uToken.updateOverdueInfo(borrower);
        uint256 totalFrozenBefore = userManager.totalFrozen();
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 totalFrozenAfter = userManager.totalFrozen();
        assertEq(totalFrozenBefore - totalFrozenAfter, vouchOutstanding);
    }

    function testDebtWriteOffTotalStakedAmount() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        uint256 totalStakedBefore = userManager.totalStaked();
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 totalStakedAfter = userManager.totalStaked();
        assertEq(totalStakedBefore - totalStakedAfter, vouchOutstanding);
    }

    function testCannotDebtWriteOffAmountZero() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        vm.prank(staker);
        vm.expectRevert(UserManager.AmountZero.selector);
        userManager.debtWriteOff(staker, borrower, 0);
    }

    function testCannotDebtWriteOffNotOverdue() public {
        vm.prank(staker);
        vm.expectRevert(UserManager.NotOverdue.selector);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
    }

    function testCannotDebtWriteOffMoreThanLocked() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        vm.prank(staker);
        vm.expectRevert(UserManager.ExceedsLocked.selector);
        userManager.debtWriteOff(staker, borrower, 1000 ether);
    }

    function testCannotDebtWriteOffNotPastMaxOverdue() public {
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        vm.expectRevert(UserManager.AuthFailed.selector);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
    }

    function testDebtWriteOffAfterMaxOverdue() public {
        vm.roll(block.number + uToken.overdueBlocks() + userManager.maxOverdue() + 1);
        uint256 balBefore = userManager.getStakerBalance(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 balAfter = userManager.getStakerBalance(staker);
        assertEq(balBefore - balAfter, vouchOutstanding);
    }
}
