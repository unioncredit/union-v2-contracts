pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";
import {UUPSProxy} from "union-v1.5-contracts/UUPSProxy.sol";
import {AssetManagerMock} from "union-v1.5-contracts/mocks/AssetManagerMock.sol";
import {UnionTokenMock} from "union-v1.5-contracts/mocks/UnionTokenMock.sol";
import {FaucetERC20} from "union-v1.5-contracts/mocks/FaucetERC20.sol";
import {ComptrollerMock} from "union-v1.5-contracts/mocks/ComptrollerMock.sol";
import {UTokenMock} from "union-v1.5-contracts/mocks/UTokenMock.sol";

contract TestUserManagerBase is TestWrapper {
    UserManager public userManager;
    address public constant ADMIN = address(1);
    address public constant MEMBER = address(1);
    address public constant ACCOUNT = address(2);

    function setUp() public virtual {
        uint256 maxOverdue = 1000;
        uint256 effectiveCount = 3;
        address userManagerLogic = address(new UserManager());

        deployMocks();

        userManager = UserManager(
            deployProxy(
                userManagerLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address,uint256,uint256)",
                    address(assetManagerMock),
                    address(unionTokenMock),
                    address(daiMock),
                    address(comptrollerMock),
                    ADMIN,
                    maxOverdue,
                    effectiveCount
                )
            )
        );

        vm.startPrank(ADMIN);
        userManager.setUToken(address(uTokenMock));
        userManager.addMember(MEMBER);
        vm.stopPrank();

        daiMock.mint(MEMBER, 100 ether);
        vm.prank(MEMBER);
        daiMock.approve(address(userManager), type(uint256).max);
    }
}