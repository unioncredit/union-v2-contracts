pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {AssetManagerMock} from "union-v2-contracts/mocks/AssetManagerMock.sol";
import {UnionTokenMock} from "union-v2-contracts/mocks/UnionTokenMock.sol";
import {FaucetERC20} from "union-v2-contracts/mocks/FaucetERC20.sol";
import {ComptrollerMock} from "union-v2-contracts/mocks/ComptrollerMock.sol";
import {UTokenMock} from "union-v2-contracts/mocks/UTokenMock.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestUpgradeComtrollerAndUserManager is TestWrapper {
    UserManager public userManager;
    Comptroller public comptroller;
    UnionTokenMock public newUnionTokenMock;

    address public constant ADMIN = address(0);

    function setUp() public virtual {
        newUnionTokenMock = new UnionTokenMock("UnionMock", "UNM");
        address userManagerLogic = address(new UserManager());
        address comptrollerLogic = address(new Comptroller());
        deployMocks();

        userManager = UserManager(
            deployProxy(
                userManagerLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                    address(assetManagerMock),
                    address(unionTokenMock),
                    address(daiMock),
                    address(comptrollerMock),
                    ADMIN,
                    1000,
                    3,
                    500,
                    1000
                )
            )
        );

        comptroller = Comptroller(
            deployProxy(
                comptrollerLogic,
                abi.encodeWithSignature(
                    "__Comptroller_init(address,address,address,uint256)",
                    ADMIN,
                    unionTokenMock,
                    marketRegistryMock,
                    1000000
                )
            )
        );
    }

    function testUpgradeComptorller() public {
        vm.startPrank(ADMIN);
        address newComptrollerLogic = address(new Comptroller());
        bytes memory data = abi.encodeWithSignature("changeUnionToken(address)", address(newUnionTokenMock));
        comptroller.upgradeToAndCall(newComptrollerLogic, data);
        assertEq(address(comptroller.unionToken()), address(newUnionTokenMock));
        vm.stopPrank();
    }

    function testUpgradeUserManager() public {
        vm.startPrank(ADMIN);
        address newUserManagerLogic = address(new UserManager());
        bytes memory data = abi.encodeWithSignature("changeUnionToken(address)", address(newUnionTokenMock));
        userManager.upgradeToAndCall(newUserManagerLogic, data);
        assertEq(userManager.unionToken(), address(newUnionTokenMock));
        vm.stopPrank();
    }
}
