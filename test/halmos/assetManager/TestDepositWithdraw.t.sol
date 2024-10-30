pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestDepositWithdraw is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;

    function setUp() public override {
        super.setUp();

        daiMock.mint(address(this), daiAmount);
        daiMock.approve(address(assetManager), daiAmount);
        vm.startPrank(ADMIN);
        assetManager.addToken(address(daiMock));
        assetManager.addAdapter(address(adapterMock));
        vm.stopPrank();
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(daiMock), a);
        marketRegistryMock.setUToken(address(daiMock), b);
    }

    function testDeposit() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        adapterMock.setCeiling(address(daiMock), amount);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(daiMock), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), amount);
        assertEq(assetManager.balances(address(this), address(daiMock)), amount);
        assertEq(daiMock.balanceOf(address(assetManager)), 0);
    }

    function testDepositWhenAdapterRevert() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        adapterMock.setRevert();
        adapterMock.setCeiling(address(daiMock), amount);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(daiMock), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), amount);
        assertEq(assetManager.balances(address(this), address(daiMock)), amount);
        assertEq(daiMock.balanceOf(address(assetManager)), amount);
    }

    function testDepositAsUToken() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        setTokens(address(123), address(this));
        vm.stopPrank();
        uint256 balBefore = daiMock.balanceOf(address(assetManager));
        assetManager.deposit(address(daiMock), amount);
        uint256 balAfter = daiMock.balanceOf(address(assetManager));

        assertEq(assetManager.totalPrincipal(address(daiMock)), 0);
        assertEq(assetManager.balances(address(this), address(daiMock)), 0);
        assertEq(balAfter - balBefore, amount);
    }

    function testWithdraw() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        setTokens(address(123), address(this));
        vm.stopPrank();
        assetManager.deposit(address(daiMock), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(123)), amount);
    }

    function testWithdrawAsUToken() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();
        assetManager.deposit(address(daiMock), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(123)), amount);
        assertEq(assetManager.totalPrincipal(address(daiMock)), 0);
        assertEq(assetManager.balances(address(this), address(daiMock)), 0);
    }
}
