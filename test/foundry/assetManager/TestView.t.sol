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
        marketRegistryMock.setUserManager(address(erc20Mock), a);
        marketRegistryMock.setUToken(address(erc20Mock), b);
    }

    function testGetPoolBalance(uint256 amount) public {
        erc20Mock.mint(address(assetManager), amount);
        assertEq(amount, assetManager.getPoolBalance(address(erc20Mock)));
    }

    function testGetPoolBalanceSupportedMarket(uint256 adapterAmount, uint256 mintAmount) public {
        vm.assume(adapterAmount <= 1000 ether && mintAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(erc20Mock));
        erc20Mock.mint(address(assetManager), mintAmount);
        vm.stopPrank();
        assertEq(mintAmount + adapterAmount, assetManager.getPoolBalance(address(erc20Mock)));
    }

    function testGetLoanableAmount(uint256 amount) public {
        erc20Mock.mint(address(assetManager), amount);
        assertEq(assetManager.getLoanableAmount(address(erc20Mock)), amount);
    }

    function testGetLoanableAmountWithPrincipal(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000000 * UNIT);
        erc20Mock.mint(address(assetManager), amount);
        vm.startPrank(ADMIN);
        setTokens(address(this), address(this));
        assetManager.addToken(address(erc20Mock));
        vm.stopPrank();
        erc20Mock.mint(address(this), amount);
        erc20Mock.approve(address(assetManager), amount);
        assetManager.deposit(address(erc20Mock), amount);
        assertEq(assetManager.getLoanableAmount(address(erc20Mock)), amount * 2);
    }

    function testTotalSupply(uint256 adapterAmount) public {
        vm.assume(adapterAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(erc20Mock));
        vm.stopPrank();
        assertEq(adapterAmount, assetManager.totalSupply(address(erc20Mock)));
    }

    function testTotalSupplyView(uint256 adapterAmount) public {
        vm.assume(adapterAmount <= 1000 ether);
        FakeAdapter fakeAdapter = new FakeAdapter(adapterAmount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(fakeAdapter));
        assetManager.addToken(address(erc20Mock));
        vm.stopPrank();
        assertEq(adapterAmount, assetManager.totalSupplyView(address(erc20Mock)));
    }

    function testIsMarketSupported() public {
        assert(!assetManager.isMarketSupported(address(erc20Mock)));
        vm.prank(ADMIN);
        assetManager.addToken(address(erc20Mock));
        assert(assetManager.isMarketSupported(address(erc20Mock)));
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
        assetManager.addToken(address(erc20Mock));
        assertEq(assetManager.supportedTokensCount(), 1);
    }
}
