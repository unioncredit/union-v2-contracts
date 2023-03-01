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

contract TestWriteOffDebtAndWithdrawRewards is TestWrapper {
    UserManager public userManager;
    Comptroller public comptroller;

    address public constant ADMIN = address(0);
    address public constant MEMBER = address(1);
    address public constant ACCOUNT = address(2);
    uint256 public constant maxOverdue = 1000;
    uint256 public constant effectiveCount = 3;
    uint256 public constant maxVouchers = 500;
    uint256 public constant maxVouchees = 1000;

    address staker = MEMBER;
    address borrower = ACCOUNT;

    function setUp() public virtual {
        address userManagerLogic = address(new UserManager());

        deployMocks();

        // deploy comptroller
        address comptrollerLogic = address(new Comptroller());

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

        // deploy user manager
        userManager = UserManager(
            deployProxy(
                userManagerLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                    address(assetManagerMock),
                    address(unionTokenMock),
                    address(daiMock),
                    address(comptroller),
                    ADMIN,
                    maxOverdue,
                    effectiveCount,
                    maxVouchers,
                    maxVouchees
                )
            )
        );

        vm.startPrank(ADMIN);
        // setup comptroller
        unionTokenMock.mint(address(comptroller), 1_000_000 ether);
        marketRegistryMock.setUserManager(address(daiMock), address(userManager));

        // setup userManager
        userManager.setUToken(address(uTokenMock));
        userManager.addMember(MEMBER);

        vm.stopPrank();

        uint96 stakeAmount = 100 ether;
        daiMock.mint(MEMBER, stakeAmount);

        vm.startPrank(staker);
        daiMock.approve(address(userManager), type(uint256).max);
        userManager.stake(stakeAmount);
        userManager.updateTrust(borrower, stakeAmount);
        vm.stopPrank();
    }

    function testDebtWriteOffAndWithdrawRewards(uint96 writeOffAmount, uint96 amount) public {
        uint256 currBlock = block.number;

        uint96 borrowAmount = 20 ether;

        // 1st borrow
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, borrowAmount, true);

        // 2nd borrow
        vm.roll(++currBlock);
        userManager.getStakeInfo(staker);

        vm.mockCall(
            address(uTokenMock),
            abi.encodeWithSelector(UToken.checkIsOverdue.selector, borrower),
            abi.encode(true)
        );
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, borrowAmount, true);
        uTokenMock.setOverdueBlocks(0);
        uTokenMock.setLastRepay(currBlock);

        // write off debt
        vm.roll(++currBlock);

        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, borrowAmount * 2);
        uTokenMock.setLastRepay(0);

        comptroller.calculateRewards(staker, address(daiMock));

        vm.roll(++currBlock);
        comptroller.calculateRewards(staker, address(daiMock));
        emit log_uint(block.number);

        vm.roll(++currBlock);
        comptroller.withdrawRewards(staker, address(daiMock));
        comptroller.calculateRewards(staker, address(daiMock));
        emit log_uint(block.number);
    }
}
