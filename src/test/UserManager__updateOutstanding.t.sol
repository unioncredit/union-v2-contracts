pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__updateOutstanding is TestWrapper {
    uint256 public borrowAmount = 10 ether;
    uint256 public repayAmount = (10 ether * 10) / 100;

    function setUp() public override {
        super.setUp();
        initStakers();
        registerMember(MEMBER_4);
    }

    function testUpdateOutstandingLocksFirstInFirst() public {
        vm.startPrank(MEMBER_4);
        (, , uint256 outstanding0) = userManager.vouchers(MEMBER_4, 0);
        (, , uint256 outstanding1) = userManager.vouchers(MEMBER_4, 1);
        assertEq(outstanding0 + outstanding1, 0);
        uint256 fee = uToken.calculatingFee(trustAmount);
        uToken.borrow(trustAmount);
        (, , uint256 outstandingAfter0) = userManager.vouchers(MEMBER_4, 0);
        (, , uint256 outstandingAfter1) = userManager.vouchers(MEMBER_4, 1);
        assertEq(outstandingAfter0, trustAmount);
        assertEq(outstandingAfter1, fee);
        vm.stopPrank();
    }

    function testUpdateOutstandingLocksEntireCreditline() public {
        uint256 creditLimit = userManager.getCreditLimit(MEMBER_4);
        uint256 vouchersCount = userManager.getVoucherCount(MEMBER_4);
        uint256 fee = uToken.calculatingFee(creditLimit);
        uint256 borrowAmount = creditLimit - fee;
        uint256 actualFee = uToken.calculatingFee(borrowAmount);

        vm.startPrank(MEMBER_4);
        uToken.borrow(borrowAmount);
        uint256 principal = borrowAmount + actualFee;

        for (uint256 i = 0; i < vouchersCount; i++) {
            (, uint256 amount, uint256 outstanding) = userManager.vouchers(MEMBER_4, i);
            if (i == vouchersCount - 1) {
                assertEq(principal, outstanding);
            } else {
                assertEq(amount, outstanding);
            }
            principal -= outstanding;
        }
        vm.stopPrank();
    }

    function testUpdateOutstandingUnlocksFirstInFirst() public {
        uint256 creditLimit = userManager.getCreditLimit(MEMBER_4);
        uint256 vouchersCount = userManager.getVoucherCount(MEMBER_4);
        uint256 fee = uToken.calculatingFee(creditLimit);
        uint256 borrowAmount = creditLimit - fee;

        vm.startPrank(MEMBER_4);
        uToken.borrow(creditLimit - fee);
        (, , uint256 outstandingBefore) = userManager.vouchers(MEMBER_4, 0);
        dai.approve(address(uToken), type(uint256).max);
        uToken.repayBorrow(repayAmount);
        (, , uint256 outstandingAfter) = userManager.vouchers(MEMBER_4, 0);
        assertEq(outstandingBefore - outstandingAfter, repayAmount);
    }
}
