pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUToken__repay is TestWrapper {
  uint256 public borrowAmount = 10 ether;

  function borrow() public {
    initStakers();
    registerMember(MEMBER_4);
    vm.startPrank(MEMBER_4);
    uToken.borrow(borrowAmount);
    vm.stopPrank();
  }

  function testRepay() public {
    borrow();

    uint256 repayAmount = borrowAmount * 10 / 100;
    uint256 borrowBefore = uToken.getBorrowed(MEMBER_4);

    vm.startPrank(MEMBER_4);
    dai.approve(address(uToken), type(uint256).max);
    uToken.repayBorrow(repayAmount);
    vm.stopPrank();

    uint256 borrowAfter = uToken.getBorrowed(MEMBER_4);
    assertEq(borrowBefore - borrowAfter, repayAmount);
  }  
}
