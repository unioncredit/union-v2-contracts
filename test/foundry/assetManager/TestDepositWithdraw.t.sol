pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestDepositWithdraw is TestAssetManagerBase {
    uint256 public erc20Amount = 1_000_000 * UNIT;

    function setUp() public override {
        super.setUp();

        erc20Mock.mint(address(this), erc20Amount);
        erc20Mock.approve(address(assetManager), erc20Amount);
        vm.startPrank(ADMIN);
        assetManager.addToken(address(erc20Mock));
        assetManager.addAdapter(address(adapterMock));
        vm.stopPrank();
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(erc20Mock), a);
        marketRegistryMock.setUToken(address(erc20Mock), b);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        adapterMock.setCeiling(address(erc20Mock), amount);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(erc20Mock), amount);
        assertEq(assetManager.totalPrincipal(address(erc20Mock)), amount);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), amount);
        assertEq(erc20Mock.balanceOf(address(assetManager)), 0);
    }

    function testDepositWhenAdapterRevert(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        adapterMock.setRevert();
        adapterMock.setCeiling(address(erc20Mock), amount);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(erc20Mock), amount);
        assertEq(assetManager.totalPrincipal(address(erc20Mock)), amount);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), amount);
        assertEq(erc20Mock.balanceOf(address(assetManager)), amount);
    }

    function testDepositAsUToken(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        setTokens(address(123), address(this));
        vm.stopPrank();
        uint256 balBefore = erc20Mock.balanceOf(address(assetManager));
        assetManager.deposit(address(erc20Mock), amount);
        uint256 balAfter = erc20Mock.balanceOf(address(assetManager));

        assertEq(assetManager.totalPrincipal(address(erc20Mock)), 0);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), 0);
        assertEq(balAfter - balBefore, amount);
    }

    // TODO:
    // function testDepositWithMoneyMarkets() public {}

    function testCannotDepositNotAdmin() public {
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.deposit(address(erc20Mock), 1);
    }

    function testCannotWithdrawNotAdmin() public {
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.withdraw(address(erc20Mock), address(1), 1);
    }

    function testWithdraw(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        setTokens(address(123), address(this));
        vm.stopPrank();
        assetManager.deposit(address(erc20Mock), amount);
        assetManager.withdraw(address(erc20Mock), address(123), amount);
        assertEq(erc20Mock.balanceOf(address(123)), amount);
    }

    function testWithdrawAsUToken(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(erc20Mock), amount);
        assetManager.withdraw(address(erc20Mock), address(123), amount);
        assertEq(erc20Mock.balanceOf(address(123)), amount);
        assertEq(assetManager.totalPrincipal(address(erc20Mock)), 0);
        assertEq(assetManager.balances(address(this), address(erc20Mock)), 0);
    }

    // TODO:
    // function testWithdrawWithMoneyMarkets() public {}

    function testCannotWithdrawBalanceTooLow(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.expectRevert(AssetManager.AuthFailed.selector);
        assetManager.withdraw(address(erc20Mock), address(123), amount);
    }
}
