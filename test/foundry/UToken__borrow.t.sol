pragma solidity ^0.8.0;

import "./Wrapper.sol";
import "union-v1.5-contracts/user/UserManager.sol";

contract TestUToken__borrow is TestWrapper {
    uint256 public count = 100;
    uint256 public amount = 10 ether;

    address public newMember = address(123);
    address public newerMember = address(1234);

    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < count; i++) {
            address member = address(uint160(uint256(keccak256(abi.encode(111 * i)))));

            vm.startPrank(ADMIN);
            userManager.addMember(member);
            vm.stopPrank();

            vm.startPrank(member);
            dai.mint(member, amount);
            dai.approve(address(userManager), amount);
            userManager.stake(uint128(amount));

            userManager.updateTrust(newerMember, uint128(amount));
            userManager.updateTrust(newMember, uint128(amount));
            vm.stopPrank();
        }

        unionToken.approve(address(userManager), type(uint256).max);
        userManager.registerMember(newMember);
        userManager.registerMember(newerMember);

        dai.mint(address(this), 1000000 ether);
        uToken.addReserves(dai.balanceOf(address(this)));
    }

    function testBorrow() public {
        uint256 daiBalanceBefore = dai.balanceOf(newMember);
        vm.startPrank(newMember);
        uToken.borrow(trustAmount);
        uint256 daiBalanceAfter = dai.balanceOf(newMember);
        assertEq(daiBalanceAfter - daiBalanceBefore, trustAmount);
    }

    function testBorrowFrom100() public {
        uint256 borrowAmount = (count - 1) * amount;
        vm.startPrank(newMember);
        uToken.borrow(borrowAmount);
        vm.stopPrank();
    }

    function testCreditLimitChangesAfterBorrow() public {
        uint256 borrowAmount = 20 ether;
        uint256 fee = uToken.calculatingFee(borrowAmount);
        uint256 creditLimitBefore = userManager.getCreditLimit(newMember);
        vm.startPrank(newMember);
        uToken.borrow(borrowAmount);
        uint256 creditLimitAfter = userManager.getCreditLimit(newMember);
        assertEq(creditLimitAfter, creditLimitBefore - borrowAmount - fee);
    }

    function testCannotBorrowMoreThanCreditLimit() public {
        uint256 creditLimit = userManager.getCreditLimit(newMember);
        vm.startPrank(newMember);
        vm.expectRevert(UserManager.OutstandingRemaining.selector);
        uToken.borrow(creditLimit);
        vm.stopPrank();
    }

    function testBorrowUpdatesAccountBorrows() public {
        uint256 borrowedBefore = uToken.getBorrowed(newMember);
        vm.prank(newMember);
        uToken.borrow(trustAmount);
        uint256 fee = uToken.calculatingFee(trustAmount);
        uint256 borrowedAfter = uToken.getBorrowed(newMember);
        assertEq(borrowedAfter - borrowedBefore, trustAmount + fee);
    }

    function testBorrowUpdatesTotalBorrow() public {
        uint256 borrowedBefore = uToken.totalBorrows();
        vm.prank(newMember);
        uToken.borrow(trustAmount);
        uint256 fee = uToken.calculatingFee(trustAmount);
        uint256 borrowedAfter = uToken.totalBorrows();
        assertEq(borrowedAfter - borrowedBefore, trustAmount + fee);
    }

    function testBorrowUpdatesLasRepay() public {
        assertEq(uToken.getLastRepay(newMember), 0);
        vm.prank(newMember);
        uToken.borrow(trustAmount);
        assert(uToken.getLastRepay(newMember) != 0);
    }

    function testBorrowAddsFeeToReserves() public {
        uint256 reservesBefore = uToken.totalReserves();
        vm.prank(newMember);
        uToken.borrow(trustAmount);
        uint256 fee = uToken.calculatingFee(trustAmount);
        assertEq(uToken.totalReserves() - reservesBefore, fee);
    }

    function testCannotBorrowLessThanMinBorrow() public {
        vm.prank(newMember);
        vm.expectRevert(UToken.AmountLessMinBorrow.selector);
        uToken.borrow(1);
    }

    function testCannotBorrowMoreThanMaxBorrow() public {
        vm.prank(newMember);
        vm.expectRevert(UToken.AmountExceedGlobalMax.selector);
        uToken.borrow(type(uint256).max);
    }

    function testCannotBorrowWhenOverdue() public {
        vm.prank(newMember);
        uToken.borrow(trustAmount);
        vm.roll(block.number + uToken.overdueBlocks() + 1);
        assert(uToken.checkIsOverdue(newMember));
        vm.prank(newMember);
        vm.expectRevert(UToken.MemberIsOverdue.selector);
        uToken.borrow(trustAmount);
    }

    function testCannotBorrowWhenAvailableStakeZero() public {
        uint256 creditLimit = userManager.getCreditLimit(newMember);
        uint256 fee = uToken.calculatingFee(creditLimit);

        vm.startPrank(newMember);
        uToken.borrow(creditLimit - fee);
        vm.stopPrank();

        vm.startPrank(newerMember);
        vm.expectRevert(UserManager.OutstandingRemaining.selector);
        uToken.borrow(creditLimit - fee);
        vm.stopPrank();
    }
}
