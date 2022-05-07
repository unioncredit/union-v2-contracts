pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUToken__borrow is TestWrapper {
  function testBorrow() public {
    initStakers();
    registerMember(MEMBER_4);

    uint256 daiBalanceBefore = dai.balanceOf(MEMBER_4);
    vm.startPrank(MEMBER_4);
    uToken.borrow(trustAmount);
    uint256 daiBalanceAfter = dai.balanceOf(MEMBER_4);
    assertEq(daiBalanceAfter - daiBalanceBefore, trustAmount);
  }  
}
