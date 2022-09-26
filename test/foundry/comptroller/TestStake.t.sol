pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";

contract TestStake is TestComptrollerBase {
    function setUp() public override {
        super.setUp();
        uTokenMock.mint(100 ether);
        uTokenMock.transfer(MEMBER, 100 ether);
        vm.prank(MEMBER);
        uTokenMock.approve(address(comptroller), type(uint256).max);

        marketRegistryMock.setUToken(address(daiMock), address(uTokenMock));
        comptroller.setSupportUToken(address(daiMock), true);
        comptroller.setMaxStakeAmount(100 ether);
    }

    function testCannotStakeWhenUTokenNotSupport(uint96 amount) public {
        comptroller.setSupportUToken(address(daiMock), false);
        vm.expectRevert(Comptroller.NotSupport.selector);
        comptroller.stake(address(uTokenMock), amount);
    }

    function testCannotStakeWhenExceedLimit(uint96 amount) public {
        vm.assume(amount <= 100 ether && amount > 1 ether);
        comptroller.setMaxStakeAmount(1 ether);
        vm.prank(MEMBER);
        vm.expectRevert(Comptroller.StakeLimitReached.selector);
        comptroller.stake(address(uTokenMock), amount);
    }

    function testStake(uint96 amount) public {
        vm.assume(amount <= 100 ether && amount > 0);
        vm.prank(MEMBER);
        comptroller.stake(address(uTokenMock), amount);
        assertEq(comptroller.stakers(MEMBER, address(uTokenMock)), amount);
        assertEq(comptroller.uTokenTotalStaked(address(uTokenMock)), amount);
    }

    function testCannotUnStakeWhenUTokenNotSupport(uint96 amount) public {
        comptroller.setSupportUToken(address(daiMock), false);
        vm.expectRevert(Comptroller.NotSupport.selector);
        comptroller.unstake(address(uTokenMock), amount);
    }

    function testCannotUnStakeWhenExceedStake(uint96 amount) public {
        vm.assume(amount <= 100 ether && amount > 1 ether);
        vm.prank(MEMBER);
        vm.expectRevert(Comptroller.ExceedStake.selector);
        comptroller.unstake(address(uTokenMock), amount);
    }

    function testUnStake(uint96 amount) public {
        vm.assume(amount <= 100 ether && amount > 0);
        vm.startPrank(MEMBER);
        comptroller.stake(address(uTokenMock), amount);
        assertEq(comptroller.stakers(MEMBER, address(uTokenMock)), amount);
        assertEq(comptroller.uTokenTotalStaked(address(uTokenMock)), amount);
        comptroller.unstake(address(uTokenMock), amount);
        assertEq(comptroller.stakers(MEMBER, address(uTokenMock)), 0);
        assertEq(comptroller.uTokenTotalStaked(address(uTokenMock)), 0);
        vm.stopPrank();
    }
}
