pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v1.5-contracts/asset/AssetManager.sol";

contract TestDepositWithdraw is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;

    function setUp() public override {
        super.setUp();

        daiMock.mint(address(this), daiAmount);
        daiMock.approve(address(assetManager), daiAmount);
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(daiMock), a);
        marketRegistryMock.setUToken(address(daiMock), b);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        setTokens(address(this), address(123));
        assetManager.deposit(address(daiMock), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), amount);
        assertEq(assetManager.balances(address(this), address(daiMock)), amount);
    }

    function testDepositAsUToken(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        setTokens(address(123), address(this));
        uint256 balBefore = daiMock.balanceOf(address(assetManager));
        assetManager.deposit(address(daiMock), amount);
        uint256 balAfter = daiMock.balanceOf(address(assetManager));

        assertEq(assetManager.totalPrincipal(address(daiMock)), 0);
        assertEq(assetManager.balances(address(this), address(daiMock)), 0);
        assertEq(balAfter - balBefore, amount);
    }

    // TODO:
    // function testDepositWithMoneyMarkets() public {}

    function testCannotDepositNotAdmin() public {
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.deposit(address(daiMock), 1);
    }

    function testCannotWithdrawNotAdmin() public {
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.withdraw(address(daiMock), address(1), 1);
    }

    function testWithdraw(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        setTokens(address(123), address(this));
        assetManager.deposit(address(daiMock), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(123)), amount);
    }

    function testWithdrawAsUToken(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        setTokens(address(this), address(123));
        assetManager.deposit(address(daiMock), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(123)), amount);

        assertEq(assetManager.totalPrincipal(address(daiMock)), 0);
        assertEq(assetManager.balances(address(this), address(daiMock)), 0);
    }

    // TODO:
    // function testWithdrawWithMoneyMarkets() public {}

    function testCannotWithdrawBalanceTooLow(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.withdraw(address(daiMock), address(123), amount);
    }
}
