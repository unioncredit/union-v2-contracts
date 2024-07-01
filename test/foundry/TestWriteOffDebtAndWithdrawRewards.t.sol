pragma solidity ^0.8.0;
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
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
    using SafeCastUpgradeable for uint256;
    UserManager public userManager;
    Comptroller public comptroller;

    address public constant ADMIN = address(0);
    address public constant MEMBER = address(1);
    address public constant ACCOUNT = address(2);
    uint256 public constant maxOverdue = 1000;
    uint256 public constant effectiveCount = 3;
    uint256 public constant maxVouchers = 500;
    uint256 public constant maxVouchees = 1000;
    uint96 private stakeAmount = (100 * UNIT).toUint96();

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
                    address(erc20Mock),
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
        unionTokenMock.mint(address(comptroller), 1_000_000 * UNIT);
        marketRegistryMock.setUserManager(address(erc20Mock), address(userManager));

        // setup userManager
        userManager.setUToken(address(uTokenMock));
        userManager.addMember(MEMBER);

        vm.stopPrank();

        erc20Mock.mint(MEMBER, stakeAmount);

        vm.startPrank(staker);
        erc20Mock.approve(address(userManager), type(uint256).max);
        userManager.stake(stakeAmount);
        userManager.updateTrust(borrower, stakeAmount);
        vm.stopPrank();
    }

    function nearlyEqual(uint256 a, uint256 b, uint256 eps) private pure returns (bool) {
        return (a >= b && a - b <= eps) || (b > a && b - a <= eps);
    }

    function testDebtWriteOffAndWithdrawRewards(uint96 borrowAmount) public {
        vm.assume(borrowAmount > 0 && borrowAmount <= stakeAmount / 2);

        uint256 currTimestamp = block.timestamp;
        uint256 claimedRewards = 0;

        // 1st borrow
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, borrowAmount, true);
        skip(++currTimestamp);

        // 2nd borrow
        vm.mockCall(
            address(uTokenMock),
            abi.encodeWithSelector(UToken.checkIsOverdue.selector, borrower),
            abi.encode(true)
        );
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, borrowAmount, true);
        uTokenMock.setOverdueTime(0);
        uTokenMock.setLastRepay(currTimestamp);
        skip(++currTimestamp);
        // write off debt
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, borrowAmount * 2);
        uTokenMock.setLastRepay(0);

        // create a snapshot
        uint256 snapshot = vm.snapshot();
        currTimestamp = block.timestamp;
        // withdraw rewards in the same block
        claimedRewards = comptroller.withdrawRewards(staker, address(erc20Mock));
        skip(++currTimestamp);
        skip(++currTimestamp);
        // record the total rewards from the same block rewards withdraw
        uint256 rewardsFromSameBlockWithdraw = claimedRewards +
            comptroller.calculateRewards(staker, address(erc20Mock));

        // revert back to before claiming the rewards
        vm.revertTo(snapshot);
        currTimestamp = block.timestamp;
        skip(++currTimestamp);
        // withdraw rewards 1 block after the debtWriteOff() call
        claimedRewards = comptroller.withdrawRewards(staker, address(erc20Mock));
        skip(++currTimestamp);
        // record total rewards
        uint256 rewardsFromDiffBlockWithdraw = claimedRewards +
            comptroller.calculateRewards(staker, address(erc20Mock));

        emit log_named_decimal_uint("Rewards 1", rewardsFromSameBlockWithdraw, 18);
        emit log_named_decimal_uint("Rewards 2", rewardsFromDiffBlockWithdraw, 18);

        // the amounts of 2 cases should be equal with neglectable differences (100 wei)
        assertTrue(nearlyEqual(rewardsFromSameBlockWithdraw, rewardsFromDiffBlockWithdraw, 100));
    }
}
