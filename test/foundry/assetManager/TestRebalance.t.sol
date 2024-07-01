pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract FakeAdapter {
    function supportsToken(address) public pure returns (bool) {
        return true;
    }

    function withdrawAll(address token, address to) public {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, balance);
    }

    function deposit(address) public pure returns (bool) {
        return true;
    }
}

contract TestRebalance is TestAssetManagerBase {
    FakeAdapter public adapter0;
    FakeAdapter public adapter1;

    function setUp() public override {
        super.setUp();

        // set up the asset manager:
        // 1. add two fake adapters
        // 2. fund fake adapters with DAI
        // 3. add supported token
        adapter0 = new FakeAdapter();
        adapter1 = new FakeAdapter();

        uint256 amount = 100 * UNIT;
        erc20Mock.mint(address(adapter0), amount);
        erc20Mock.mint(address(adapter1), amount);
        vm.startPrank(ADMIN);
        assetManager.addAdapter(address(adapter0));
        assetManager.addAdapter(address(adapter1));
        assetManager.addToken(address(erc20Mock));
        vm.stopPrank();
    }

    function testRebalance() public {
        uint256[] memory weights = new uint256[](1);
        weights[0] = 7000;
        vm.prank(ADMIN);
        assetManager.rebalance(address(erc20Mock), weights);

        uint256 balance0 = erc20Mock.balanceOf(address(adapter0));
        uint256 balance1 = erc20Mock.balanceOf(address(adapter1));

        assertEq(balance0, 140 * UNIT);
        assertEq(balance1, 60 * UNIT);
    }

    function testRebalance5050() public {
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        vm.prank(ADMIN);
        assetManager.rebalance(address(erc20Mock), weights);

        uint256 balance0 = erc20Mock.balanceOf(address(adapter0));
        uint256 balance1 = erc20Mock.balanceOf(address(adapter1));

        assertEq(balance0, 100 * UNIT);
        assertEq(balance1, 100 * UNIT);
    }

    function testCannotRebalanceUnsupported() public {
        uint256[] memory weights = new uint256[](1);
        weights[0] = 7000;
        vm.prank(ADMIN);
        vm.expectRevert(AssetManager.UnsupportedToken.selector);
        assetManager.rebalance(address(1), weights);
    }

    function testCannotRebalanceNonAdmin() public {
        uint256[] memory weights = new uint256[](1);
        weights[0] = 7000;
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        assetManager.rebalance(address(erc20Mock), weights);
    }
}
