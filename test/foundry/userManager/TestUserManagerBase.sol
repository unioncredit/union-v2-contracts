pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {AssetManagerMock} from "union-v2-contracts/mocks/AssetManagerMock.sol";
import {UnionTokenMock} from "union-v2-contracts/mocks/UnionTokenMock.sol";
import {FaucetERC20} from "union-v2-contracts/mocks/FaucetERC20.sol";
import {ComptrollerMock} from "union-v2-contracts/mocks/ComptrollerMock.sol";
import {UTokenMock} from "union-v2-contracts/mocks/UTokenMock.sol";
import {UserManagerOp} from "union-v2-contracts/user/UserManagerOp.sol";

contract TestUserManagerBase is TestWrapper {
    UserManager public userManager;
    UserManagerOp public userManagerOp;

    address public constant ADMIN = address(1);
    address public constant MEMBER = address(1);
    address public constant ACCOUNT = address(2);
    uint256 public constant maxOverdue = 1000;
    uint256 public constant effectiveCount = 3;
    uint256 public constant maxVouchers = 500;
    uint256 public constant maxVouchees = 1000;

    function setUp() public virtual {
        address userManagerLogic = address(new UserManager());
        address userManagerOpLogic = address(new UserManagerOp());

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
                    maxOverdue,
                    effectiveCount,
                    maxVouchers,
                    maxVouchees
                )
            )
        );

        userManagerOp = UserManagerOp(
            deployProxy(
                userManagerOpLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                    address(assetManagerMock),
                    address(unionTokenMock),
                    address(daiMock),
                    address(comptrollerMock),
                    ADMIN,
                    maxOverdue,
                    effectiveCount,
                    maxVouchers,
                    maxVouchees
                )
            )
        );

        vm.startPrank(ADMIN);
        userManager.setUToken(address(uTokenMock));
        userManager.addMember(MEMBER);
        userManagerOp.setUToken(address(uTokenMock));
        userManagerOp.addMember(MEMBER);
        vm.stopPrank();

        daiMock.mint(MEMBER, 100 ether);
        daiMock.mint(address(this), 100 ether);

        daiMock.approve(address(userManager), type(uint256).max);

        vm.startPrank(MEMBER);
        daiMock.approve(address(userManager), type(uint256).max);
        daiMock.approve(address(userManagerOp), type(uint256).max);
        vm.stopPrank();
    }
}
