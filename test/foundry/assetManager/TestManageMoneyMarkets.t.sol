pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {PureTokenAdapter} from "union-v2-contracts/asset/PureTokenAdapter.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestManageMoneyMarkets is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;
    PureTokenAdapter public pureToken;

    function setUp() public override {
        super.setUp();
        address logic = address(new PureTokenAdapter());
        pureToken = PureTokenAdapter(
            deployProxy(
                logic,
                abi.encodeWithSignature("__PureTokenAdapter_init(address,address)", [ADMIN, address(assetManagerMock)])
            )
        );
    }

    function testSetMarketRegistry() public {
        assert(assetManager.marketRegistry() != address(123));
        vm.prank(ADMIN);
        assetManager.setMarketRegistry(address(123));
        assertEq(assetManager.marketRegistry(), address(123));
    }

    function testAddToken(address token) public {
        vm.prank(ADMIN);
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
    }

    function testCannotAddTokenNonAdmin(address token) public {
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.addToken(token);
    }

    function testCannotAddTokenAlreadyExists(address token) public {
        vm.prank(ADMIN);
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        vm.expectRevert(AssetManager.TokenExists.selector);
        vm.prank(ADMIN);
        assetManager.addToken(token);
    }

    function testRemoveToken(address token) public {
        vm.startPrank(ADMIN);
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        assertEq(assetManager.supportedTokensList(0), token);
        assetManager.removeToken(token);
        assert(!assetManager.isMarketSupported(token));
        vm.expectRevert();
        assetManager.supportedTokensList(0);
        vm.stopPrank();
    }

    function testCannotRemoveTokenWhenRemainingFunds() public {
        vm.startPrank(ADMIN);
        assetManager.addToken(address(daiMock));
        assetManager.addAdapter(address(pureToken));
        daiMock.mint(address(pureToken), 10000);
        vm.expectRevert(AssetManager.RemainingFunds.selector);
        assetManager.removeToken(address(daiMock));
        vm.stopPrank();
    }

    function testCannotRemoveTokenNonAdmin(address token) public {
        vm.prank(ADMIN);
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.removeToken(token);
    }

    function testAddAdapter(address adapter) public {
        vm.prank(ADMIN);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
    }

    function testAddAdapterTwice(address adapter) public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        vm.stopPrank();
    }

    function testCannotAddAdapterNonAdmin(address adapter) public {
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.addAdapter(adapter);
    }

    function testRemoveAdapter(address adapter) public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        assertEq(assetManager.withdrawSeq(0), 0);
        assetManager.removeAdapter(adapter);
        vm.expectRevert();
        assetManager.moneyMarkets(0);
        vm.expectRevert();
        assetManager.withdrawSeq(0);
        vm.stopPrank();
    }

    function testCannotRemoveAdapterNonAdmin(address adapter) public {
        vm.prank(ADMIN);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.removeAdapter(adapter);
    }

    function testCannotRemoveAdapterWhenRemainingFunds() public {
        vm.startPrank(ADMIN);
        assetManager.addToken(address(daiMock));
        assetManager.addAdapter(address(pureToken));
        daiMock.mint(address(pureToken), 10000);
        vm.expectRevert(AssetManager.RemainingFunds.selector);
        assetManager.removeAdapter(address(pureToken));
        vm.stopPrank();
    }

    function testGetMoneyMarket(uint256 _rate) public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        adapterMock.setRate(_rate);
        daiMock.mint(address(adapterMock), daiAmount);
        (uint256 rate, uint256 tokenSupply) = assetManager.getMoneyMarket(address(daiMock), 0);
        assertEq(tokenSupply, daiAmount);
        assertEq(rate, _rate);
        vm.stopPrank();
    }

    function testRemoveTokenApprovals() public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addToken(address(daiMock));
        assertEq(daiMock.allowance(address(assetManager), address(adapterMock)), type(uint256).max);
        assetManager.removeAdapter(address(adapterMock));
        assertEq(daiMock.allowance(address(assetManager), address(adapterMock)), 0);
        vm.stopPrank();
    }

    function testRemoveMarketsApprovals() public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addToken(address(daiMock));
        assertEq(daiMock.allowance(address(assetManager), address(adapterMock)), type(uint256).max);
        assetManager.removeToken(address(daiMock));
        assertEq(daiMock.allowance(address(assetManager), address(adapterMock)), 0);
        vm.stopPrank();
    }
}
