pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";
import {AdapterMock} from "union-v2-contracts/mocks/AdapterMock.sol";

contract TestDepositWithdraw is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;
    AdapterMock public adapterMock2;

    function setUp() public override {
        super.setUp();
        adapterMock2 = new AdapterMock();
        vm.startPrank(ADMIN);
        adapterMock.setFloor(address(daiMock), daiAmount);
        adapterMock2.setFloor(address(daiMock), daiAmount);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addAdapter(address(adapterMock2));
        assetManager.addToken(address(daiMock));
        vm.stopPrank();
        daiMock.mint(address(this), daiAmount);
        daiMock.approve(address(assetManager), daiAmount);
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(daiMock), a);
        marketRegistryMock.setUToken(address(daiMock), b);
    }

    function testCannotSetWithdrawSequenceNotParity(uint256[] calldata newSeq) public {
        vm.assume(newSeq.length != 2);
        vm.prank(ADMIN);
        vm.expectRevert(AssetManager.NotParity.selector);
        assetManager.setWithdrawSequence(newSeq);
    }

    function testSetWithdrawSequence() public {
        uint256[] memory newSeq = new uint256[](2);
        newSeq[0] = 1;
        newSeq[1] = 0;
        vm.prank(ADMIN);
        assetManager.setWithdrawSequence(newSeq);
        assertEq(assetManager.withdrawSeq(0), newSeq[0]);
        assertEq(assetManager.withdrawSeq(1), newSeq[1]);
    }

    function testWithdrawSequence(uint256 amount) public {
        vm.assume(amount != 0 && amount < daiAmount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(123));
        vm.stopPrank();

        assetManager.deposit(address(daiMock), amount);
        assertEq(daiMock.balanceOf(address(adapterMock)), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(adapterMock)), 0);

        uint256[] memory newSeq = new uint256[](2);
        newSeq[0] = 1;
        newSeq[1] = 0;
        vm.prank(ADMIN);
        assetManager.setWithdrawSequence(newSeq);

        vm.startPrank(address(123));
        daiMock.approve(address(assetManager), daiAmount);
        assetManager.deposit(address(daiMock), amount);
        assertEq(daiMock.balanceOf(address(adapterMock)), amount);
        daiMock.mint(address(adapterMock2), amount);
        assertEq(daiMock.balanceOf(address(adapterMock2)), amount);
        assetManager.withdraw(address(daiMock), address(123), amount);
        assertEq(daiMock.balanceOf(address(adapterMock2)), 0);
        vm.stopPrank();
    }
}
