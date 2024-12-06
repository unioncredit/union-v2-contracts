pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {PureTokenAdapter} from "union-v2-contracts/asset/PureTokenAdapter.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestManageMoneyMarkets is TestAssetManagerBase {
    uint256 public erc20Amount = 1_000_000 * UNIT;
    PureTokenAdapter public pureTokenAdapter;

    function setUp() public override {
        super.setUp();
        address logic = address(new PureTokenAdapter());
        pureTokenAdapter = PureTokenAdapter(
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
        assetManager.addToken(address(erc20Mock));
        assetManager.addAdapter(address(pureTokenAdapter));
        erc20Mock.mint(address(pureTokenAdapter), 10000);
        vm.expectRevert(AssetManager.RemainingFunds.selector);
        assetManager.removeToken(address(erc20Mock));
        vm.stopPrank();
    }

    function testRemoveTokenWhenRemainingFundsButTokenNotSupport() public {
        vm.startPrank(ADMIN);
        assetManager.addToken(address(erc20Mock));
        assetManager.addAdapter(address(pureTokenAdapter));
        //mock adapter remaining funds
        erc20Mock.mint(address(pureTokenAdapter), 10000);
        uint256 supportedTokensCountOld = assetManager.supportedTokensCount();
        //mock token not support
        vm.mockCall(
            address(pureTokenAdapter),
            abi.encodeWithSelector(PureTokenAdapter.supportsToken.selector, erc20Mock),
            abi.encode(false)
        );
        assetManager.removeToken(address(erc20Mock));
        uint256 supportedTokensCount = assetManager.supportedTokensCount();
        assertEq(supportedTokensCount, supportedTokensCountOld - 1);
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

    function testRemoveAdapter() public {
        address[] memory adapters = new address[](9);
        adapters[0] = address(10);
        adapters[1] = address(11);
        adapters[2] = address(12);
        adapters[3] = address(13);
        adapters[4] = address(14);
        adapters[5] = address(15);
        adapters[6] = address(16);
        adapters[7] = address(17);
        adapters[8] = address(18);
        vm.startPrank(ADMIN);
        //one adapter
        assetManager.addAdapter(adapters[0]);
        assertEq(address(assetManager.moneyMarkets(0)), adapters[0]);
        assertEq(address(assetManager.withdrawSeq(0)), adapters[0]);
        assetManager.removeAdapter(adapters[0]);
        vm.expectRevert();
        assetManager.moneyMarkets(0);
        vm.expectRevert();
        assetManager.withdrawSeq(0);

        //mutil adapter
        for (uint i = 0; i < adapters.length; i++) {
            assetManager.addAdapter(adapters[i]);
            assertEq(address(assetManager.moneyMarkets(i)), adapters[i]);
        }
        uint removeIndex = adapters.length / 2;
        address removeAdapter = adapters[removeIndex];
        address nextAdapter = adapters[removeIndex + 1];
        assetManager.removeAdapter(removeAdapter);
        assertEq(address(assetManager.moneyMarkets(removeIndex)), nextAdapter);
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
        assetManager.addToken(address(erc20Mock));
        assetManager.addAdapter(address(pureTokenAdapter));
        erc20Mock.mint(address(pureTokenAdapter), 10000);
        vm.expectRevert(AssetManager.RemainingFunds.selector);
        assetManager.removeAdapter(address(pureTokenAdapter));
        vm.stopPrank();
    }

    function testRemoveAdapterWhenRemainingFundsButAdapterNotSupport() public {
        vm.startPrank(ADMIN);
        assetManager.addToken(address(erc20Mock));
        assetManager.addAdapter(address(adapterMock));
        erc20Mock.mint(address(adapterMock), 10000);
        adapterMock.setSupport(true);
        assetManager.removeAdapter(address(adapterMock));
        vm.stopPrank();
    }

    function testGetMoneyMarket(uint256 _rate) public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        adapterMock.setRate(_rate);
        erc20Mock.mint(address(adapterMock), erc20Amount);
        (uint256 rate, uint256 tokenSupply) = assetManager.getMoneyMarket(address(erc20Mock), 0);
        assertEq(tokenSupply, erc20Amount);
        assertEq(rate, _rate);
        vm.stopPrank();
    }

    function testRemoveTokenApprovals() public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addToken(address(erc20Mock));
        assertEq(erc20Mock.allowance(address(assetManager), address(adapterMock)), type(uint256).max);
        assetManager.removeAdapter(address(adapterMock));
        assertEq(erc20Mock.allowance(address(assetManager), address(adapterMock)), 0);
        vm.stopPrank();
    }

    function testRemoveMarketsApprovals() public {
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapterMock));
        assetManager.addToken(address(erc20Mock));
        assertEq(erc20Mock.allowance(address(assetManager), address(adapterMock)), type(uint256).max);
        assetManager.removeToken(address(erc20Mock));
        assertEq(erc20Mock.allowance(address(assetManager), address(adapterMock)), 0);
        vm.stopPrank();
    }
}
