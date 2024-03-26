pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestDebtWriteOff is TestAssetManagerBase {
    uint256 public erc20Amount = 1_000_000 * UNIT;

    function setUp() public override {
        super.setUp();

        erc20Mock.mint(address(this), erc20Amount);
        erc20Mock.approve(address(assetManager), erc20Amount);
        vm.startPrank(ADMIN);
        marketRegistryMock.setUToken(address(erc20Mock), ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), ADMIN);
        vm.stopPrank();
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(erc20Mock), a);
        marketRegistryMock.setUToken(address(erc20Mock), b);
    }

    function testCannotDebtWriteOffWhenInsufficientBalance(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.debtWriteOff(address(erc20Mock), amount);
    }

    function testDebtWriteOff(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(erc20Mock), amount);
        assertEq(assetManager.totalPrincipal(address(erc20Mock)), amount);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), amount);
        assetManager.debtWriteOff(address(erc20Mock), amount);
        assertEq(assetManager.totalPrincipal(address(erc20Mock)), 0);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), 0);
    }
}
