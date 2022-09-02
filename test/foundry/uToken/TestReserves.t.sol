pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestReserves is TestUTokenBase {

    function setUp() public override {
        super.setUp();
    }

    function testAddAndRemoveReserve(uint256 addReserveAmount) public {
        vm.assume(addReserveAmount > 0 && addReserveAmount <= 100 ether);

        uint256 totalReserves = uToken.totalReserves();
        assertEq(0, totalReserves);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), addReserveAmount);
        uToken.addReserves(addReserveAmount);

        vm.stopPrank();

        totalReserves = uToken.totalReserves();
        assertEq(totalReserves, addReserveAmount);

        uint256 daiBalanceBefore = daiMock.balanceOf(ALICE);

        vm.startPrank(ADMIN);

        uToken.removeReserves(ALICE, addReserveAmount);
        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalanceBefore + addReserveAmount);
    }
}
