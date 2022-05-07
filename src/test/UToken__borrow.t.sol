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

    function testBorrowFrom100() public {
        uint256 count = 100;
        uint256 amount = 10 ether;
        address newMember = address(123);

        for (uint256 i = 0; i < count; i++) {
            address member = address(uint160(uint256(keccak256(abi.encode(111 * i)))));

            vm.startPrank(ADMIN);
            userManager.addMember(member);
            vm.stopPrank();

            vm.startPrank(member);
            dai.mint(member, amount);
            dai.approve(address(userManager), amount);
            userManager.stake(amount);
            userManager.updateTrust(newMember, amount);
            vm.stopPrank();
        }

        uint256 memberFee = userManager.newMemberFee();
        unionToken.approve(address(userManager), memberFee);
        userManager.registerMember(newMember);

        uint256 borrowAmount = (count - 1) * amount;
        vm.startPrank(newMember);
        uToken.borrow(borrowAmount);
        vm.stopPrank();
    }
}
