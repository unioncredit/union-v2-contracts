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
        assert(uToken.checkIsOverdue(borrower));
        uint256 balBefore = userManager.getStakerBalance(staker);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, vouchOutstanding);
        uint256 balAfter = userManager.getStakerBalance(staker);
        assertEq(balBefore - balAfter, vouchOutstanding);
    }
    // function testDebtWriteOffVouchAmount() public {}
    // function testDebtWriteOffFrozenAmount() public {}
    // function testDebtWriteOffTotalFrozenAmount() public {}
    // function testDebtWriteOffTotalStakedAmount() public {}

    // function testCannotDebtWriteOffAmountZero() public {}
    // function testCannotDebtWriteOffNotOverdue() public {}
    // function testCannotDebtWriteOffMoreThanLocked() public {}
    // function testCannotDebtWriteOffNotPastMaxOverdue() public {}
    // function testCannotDebtWriteOffNotStaker() public {}
}
