pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager, IMoneyMarketAdapter} from "union-v2-contracts/asset/AssetManager.sol";
import {AdapterMock} from "union-v2-contracts/mocks/AdapterMock.sol";

contract TestDepositWithdraw is TestAssetManagerBase {
    uint256 public erc20Amount = 1_000_000 * UNIT;
    AdapterMock public adapterMock2;

    function setUp() public override {
        super.setUp();
        adapterMock2 = new AdapterMock();
        vm.startPrank(ADMIN);
        adapterMock.setFloor(address(erc20Mock), erc20Amount);
        adapterMock2.setFloor(address(erc20Mock), erc20Amount);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addAdapter(address(adapterMock2));
        assetManager.addToken(address(erc20Mock));
        vm.stopPrank();
        erc20Mock.mint(address(this), erc20Amount);
        erc20Mock.approve(address(assetManager), erc20Amount);
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(erc20Mock), a);
        marketRegistryMock.setUToken(address(erc20Mock), b);
    }

    function testCannotSetWithdrawSequenceNotParity(address[] calldata newSeq) public {
        vm.assume(newSeq.length != 2);
        vm.prank(ADMIN);
        vm.expectRevert(AssetManager.NotParity.selector);
        assetManager.setWithdrawSequence(newSeq);
    }

    function testCannotSetWithdrawSequenceUseErrorAddress() public {
        address[] memory newSeq = new address[](2);
        newSeq[0] = address(2);
        newSeq[1] = address(3);
        vm.prank(ADMIN);
        vm.expectRevert(AssetManager.ParamsError.selector);
        assetManager.setWithdrawSequence(newSeq);
    }

    function testSetWithdrawSequence() public {
        address[] memory newSeq = new address[](2);
        newSeq[0] = address(adapterMock2);
        newSeq[1] = address(adapterMock);
        vm.prank(ADMIN);
        assetManager.setWithdrawSequence(newSeq);
        assertEq(address(assetManager.withdrawSeq(0)), address(newSeq[0]));
        assertEq(address(assetManager.withdrawSeq(1)), address(newSeq[1]));
    }

    function testWithdrawSequence(uint256 amount) public {
        vm.assume(amount != 0 && amount < erc20Amount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();

        assetManager.deposit(address(erc20Mock), amount);
        assertEq(erc20Mock.balanceOf(address(adapterMock)), amount);
        assetManager.withdraw(address(erc20Mock), address(123), amount);
        assertEq(erc20Mock.balanceOf(address(adapterMock)), 0);

        address[] memory newSeq = new address[](2);
        newSeq[0] = address(adapterMock2);
        newSeq[1] = address(adapterMock);
        vm.prank(ADMIN);
        assetManager.setWithdrawSequence(newSeq);

        vm.startPrank(address(123));
        erc20Mock.approve(address(assetManager), erc20Amount);
        assetManager.deposit(address(erc20Mock), amount);
        assertEq(erc20Mock.balanceOf(address(adapterMock)), amount);
        erc20Mock.mint(address(adapterMock2), amount);
        assertEq(erc20Mock.balanceOf(address(adapterMock2)), amount);
        assetManager.withdraw(address(erc20Mock), address(123), amount);
        assertEq(erc20Mock.balanceOf(address(adapterMock2)), 0);
        vm.stopPrank();
    }
}
