pragma solidity ^0.8.0;

import {TestAssetManagerBase} from "./TestAssetManagerBase.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestInit is TestAssetManagerBase {
    function setUp() public override {
        super.setUp();
    }

    function testAssetManagerInit() public {
        AssetManager logic = new AssetManager();
        AssetManager _assetManager = AssetManager(deployProxy(address(logic), ""));
        _assetManager.__AssetManager_init(ADMIN, address(marketRegistryMock));
        assertEq(_assetManager.isAdmin(ADMIN), true);
        assertEq(_assetManager.marketRegistry(), address(marketRegistryMock));
    }
}
