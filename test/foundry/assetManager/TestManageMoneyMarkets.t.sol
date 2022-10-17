pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestManageMoneyMarkets is TestAssetManagerBase {
    uint256 public daiAmount = 1_000_000 ether;

    function setUp() public override {
        super.setUp();
    }

    function testSetMarketRegistry() public {
        assert(assetManager.marketRegistry() != address(123));
        assetManager.setMarketRegistry(address(123));
        assertEq(assetManager.marketRegistry(), address(123));
    }

    function testAddToken(address token) public {
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
    }

    function testCannotAddTokenNonAdmin(address token) public {
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.addToken(token);
    }

    function testCannotAddTokenAlreadyExists(address token) public {
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        vm.expectRevert(AssetManager.TokenExists.selector);
        assetManager.addToken(token);
    }

    function testRemoveToken(address token) public {
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        assertEq(assetManager.supportedTokensList(0), token);
        assetManager.removeToken(token);
        assert(!assetManager.isMarketSupported(token));
        vm.expectRevert();
        assetManager.supportedTokensList(0);
    }

    function testCannotRemoveTokenNonAdmin(address token) public {
        assetManager.addToken(token);
        assert(assetManager.isMarketSupported(token));
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.removeToken(token);
    }

    function testAddAdapter(address adapter) public {
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
    }

    function testAddAdapterTwice(address adapter) public {
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
    }

    function testCannotAddAdapterNonAdmin(address adapter) public {
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.addAdapter(adapter);
    }

    function testRemoveAdapter(address adapter) public {
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        assetManager.removeAdapter(adapter);
        vm.expectRevert();
        assetManager.moneyMarkets(0);
    }

    function testCannotRemoveAdapterNonAdmin(address adapter) public {
        assetManager.addAdapter(adapter);
        assertEq(address(assetManager.moneyMarkets(0)), adapter);
        vm.prank(address(123));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.removeAdapter(adapter);
    }

    function testGetMoneyMarket(uint256 _rate) public {
        assetManager.addAdapter(address(adapterMock));
        adapterMock.setRate(_rate);
        daiMock.mint(address(adapterMock), daiAmount);
        (uint256 rate, uint256 tokenSupply) = assetManager.getMoneyMarket(address(daiMock), 0);
        assertEq(tokenSupply, daiAmount);
        assertEq(rate, _rate);
    }
}
