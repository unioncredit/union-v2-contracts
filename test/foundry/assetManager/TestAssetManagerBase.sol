pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestAssetManagerBase is TestWrapper {
    AssetManager public assetManager;

    address public constant ADMIN = address(0);

    function setUp() public virtual {
        deployMocks();
        AssetManager logic = new AssetManager();
        assetManager = AssetManager(
            deployProxy(
                address(logic),
                abi.encodeWithSignature("__AssetManager_init(address,address)", [ADMIN, address(marketRegistryMock)])
            )
        );
    }
}
