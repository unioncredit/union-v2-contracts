pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUToken__repay is TestWrapper {
    uint256 public borrowAmount = 10 ether;
    uint256 public repayAmount = (10 ether * 10) / 100;

    function toReservesAmount(uint256 amount) internal view returns (uint256) {
        return (amount * uToken.reserveFactorMantissa()) / uToken.WAD();
    }

    function borrow() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        uToken.borrow(borrowAmount);
        vm.stopPrank();
    }

    function testRepay() public {
        borrow();

        uint256 borrowBefore = uToken.getBorrowed(MEMBER_4);
        vm.startPrank(MEMBER_4);
        dai.approve(address(uToken), type(uint256).max);
        uToken.repayBorrow(repayAmount);
        vm.stopPrank();
        uint256 borrowAfter = uToken.getBorrowed(MEMBER_4);
        assertEq(borrowBefore - borrowAfter, repayAmount);
    }

    function testRepayUpdatesCreditLimit() public {
        borrow();

        uint256 creditLimitBefore = userManager.getCreditLimit(MEMBER_4);
        vm.startPrank(MEMBER_4);
        dai.approve(address(uToken), type(uint256).max);
        uToken.accrueInterest();
        uint256 interest = uToken.calculatingInterest(MEMBER_4);
        uToken.repayBorrow(repayAmount);
        vm.stopPrank();
        uint256 creditLimitAfter = userManager.getCreditLimit(MEMBER_4);
        assertEq(creditLimitAfter - creditLimitBefore, repayAmount - interest);
    }

    function testRepayAccruesInterest() public {
        borrow();
        vm.roll(block.number + 100);
        vm.startPrank(MEMBER_4);
        dai.approve(address(uToken), type(uint256).max);
        uToken.accrueInterest();
        uint256 interest = uToken.calculatingInterest(MEMBER_4);
        assert(interest != 0);
        uToken.repayBorrow(interest + 1);
        assertEq(uToken.calculatingInterest(MEMBER_4), 0);
        vm.stopPrank();
    }

    function testCannotRepayZero() public {
        borrow();
        vm.startPrank(MEMBER_4);
        dai.approve(address(uToken), type(uint256).max);
        vm.expectRevert(UToken.AmountZero.selector);
        uToken.repayBorrow(0);
        vm.stopPrank();
    }

    function testRepayUpdatesReserveAmount() public {
        borrow();
        vm.startPrank(MEMBER_4);
        uint256 reservesBefore = uToken.totalReserves();
        dai.approve(address(uToken), type(uint256).max);
        uint256 interest = uToken.calculatingInterest(MEMBER_4);
        uToken.repayBorrow(repayAmount);
        assertEq(uToken.totalReserves() - reservesBefore, toReservesAmount(interest));
        vm.stopPrank();
    }

    function testRepayUpdatesAccountBorrows() public {
        borrow();
        uint256 borrowBefore = uToken.getBorrowed(MEMBER_4);
        vm.startPrank(MEMBER_4);
        dai.approve(address(uToken), type(uint256).max);
        uint256 interest = uToken.calculatingInterest(MEMBER_4);
        uToken.repayBorrow(repayAmount);
        uint256 borrowAfter = uToken.getBorrowed(MEMBER_4);
        assertEq(borrowBefore - borrowAfter, repayAmount - interest);
        vm.stopPrank();
    }

    function testRepayTotalAmountUpdatesLastRepayAsZero() public {
        borrow();
        vm.startPrank(MEMBER_4);
        dai.mint(MEMBER_4, 1000000 ether);
        dai.approve(address(uToken), type(uint256).max);
        uToken.repayBorrow(type(uint256).max);
        uint256 lasyRepay = uToken.getLastRepay(MEMBER_4);
        assertEq(lasyRepay, 0);
        vm.stopPrank();
      
    }
}
