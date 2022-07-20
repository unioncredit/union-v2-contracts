pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {AssetManager} from "union-v1.5-contracts/asset/AssetManager.sol";

contract TestAssetManagerBase is TestWrapper {
    AssetManager public assetManager;

    function setUp() public virtual {
        deployMocks();
        AssetManager logic = new AssetManager();
        assetManager = AssetManager(
            deployProxy(address(logic), abi.encodeWithSignature("__AssetManager_init(address)", [marketRegistryMock]))
        );
    }
}
