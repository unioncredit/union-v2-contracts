pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

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

    function testRemoveReserveWhenRemaining(uint256 addReserveAmount) public {
        vm.assume(addReserveAmount > 1 ether && addReserveAmount <= 100 ether);

        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), addReserveAmount);
        uToken.addReserves(addReserveAmount);
        vm.stopPrank();

        uint256 totalReserves = uToken.totalReserves();
        assertEq(totalReserves, addReserveAmount);

        vm.startPrank(ADMIN);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, daiMock, ALICE, addReserveAmount),
            abi.encode(1 ether)
        );
        uToken.removeReserves(ALICE, addReserveAmount);
        uint256 totalReservesAfter = uToken.totalReserves();
        assertEq(totalReservesAfter, totalReserves - addReserveAmount + 1 ether);
    }
}
