pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";

contract FakeAdapter {
    uint256 public supply;

    constructor(uint256 _supply) {
        supply = _supply;
    }

    function supportsToken(address) public pure returns (bool) {
        return true;
    }

    function getSupply(address) public view returns (uint256) {
        return supply;
    }

    function getSupplyView(address) public view returns (uint256) {
        return supply;
    }
}

contract TestView is TestAssetManagerBase {
    function setUp() public override {
        super.setUp();
    }

    function setTokens(address a, address b) public {
        marketRegistryMock.setUserManager(address(daiMock), a);
        marketRegistryMock.setUToken(address(daiMock), b);
    }

    function testGetPoolBalance(uint256 amount) public {
        daiMock.mint(address(assetManager), amount);
        assertEq(amount, assetManager.getPoolBalance(address(daiMock)));
    }

    function testGetPoolBalanceSupportedMarket(uint256 adapterAmount, uint256 mintAmount) public {
        vm.assume(adapterAmount <= 1000 ether && mintAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(daiMock));
        daiMock.mint(address(assetManager), mintAmount);
        vm.stopPrank();
        assertEq(mintAmount + adapterAmount, assetManager.getPoolBalance(address(daiMock)));
    }

    function testGetLoanableAmount(uint256 amount) public {
        daiMock.mint(address(assetManager), amount);
        assertEq(assetManager.getLoanableAmount(address(daiMock)), amount);
    }

    function testGetLoanableAmountWithPrincipal(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000000 ether);
        daiMock.mint(address(assetManager), amount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(this));
        assetManager.addToken(address(daiMock));
        vm.stopPrank();
        daiMock.mint(address(this), amount);
        daiMock.approve(address(assetManager), amount);
        assetManager.deposit(address(daiMock), amount);
        assertEq(assetManager.getLoanableAmount(address(daiMock)), amount * 2);
    }

    function testTotalSupply(uint256 adapterAmount) public {
        vm.assume(adapterAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(daiMock));
        vm.stopPrank();
        assertEq(adapterAmount, assetManager.totalSupply(address(daiMock)));
    }

    function testTotalSupplyView(uint256 adapterAmount) public {
        vm.assume(adapterAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(daiMock));
        vm.stopPrank();
        assertEq(adapterAmount, assetManager.totalSupplyView(address(daiMock)));
    }

    function testIsMarketSupported() public {
        assert(!assetManager.isMarketSupported(address(daiMock)));
        vm.prank(ADMIN);
        assetManager.addToken(address(daiMock));
        assert(assetManager.isMarketSupported(address(daiMock)));
    }

    function testMoneyMarketsCount() public {
        assertEq(assetManager.moneyMarketsCount(), 0);
        FakeAdapter fakeAdapter = new FakeAdapter(0);
        vm.prank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assertEq(assetManager.moneyMarketsCount(), 1);
    }

    function testSupportedTokensCount() public {
        assertEq(assetManager.supportedTokensCount(), 0);
        vm.prank(ADMIN);
        assetManager.addToken(address(daiMock));
        assertEq(assetManager.supportedTokensCount(), 1);
    }
}
