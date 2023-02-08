pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestDebtWriteOff is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;

    function setUp() public override {
        super.setUp();

        daiMock.mint(address(this), daiAmount);
        daiMock.approve(address(assetManager), daiAmount);
        vm.startPrank(ADMIN);
        marketRegistryMock.setUToken(address(daiMock), ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), ADMIN);
        vm.stopPrank();
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(daiMock), a);
        marketRegistryMock.setUToken(address(daiMock), b);
    }

    function testCannotDebtWriteOffWhenInsufficientBalance(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        vm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.debtWriteOff(address(daiMock), amount);
    }

    function testDebtWriteOff(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(daiMock), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), amount);
        assertEq(assetManager.balances(address(this), address(daiMock)), amount);
        assetManager.debtWriteOff(address(daiMock), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), 0);
        assertEq(assetManager.balances(address(this), address(daiMock)), 0);
    }
}
