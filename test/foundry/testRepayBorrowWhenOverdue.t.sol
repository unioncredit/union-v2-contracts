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
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestRepayBorrowWhenOverdue is TestWrapper {
    using SafeCastUpgradeable for uint256;
    UserManager public userManager;
    UToken public uToken;

    address public constant ADMIN = address(0);
    address public constant MEMBER = address(1);
    address public constant ACCOUNT = address(2);
    uint256 internal constant ORIGINATION_FEE = 0.01 ether; //1%
    uint256 internal constant ORIGINATION_FEE_MAX = 0.05 ether;
    uint256 internal MIN_BORROW = 1 * UNIT;
    uint256 internal MAX_BORROW = 100 * UNIT;
    uint256 internal constant BORROW_INTEREST_PER_BLOCK = 0.000001 ether; //0.0001%
    uint256 internal constant OVERDUE_TIME = 10;
    uint256 internal constant RESERVE_FACTOR = 0.5 ether;
    uint256 internal constant INIT_EXCHANGE_RATE = 1 ether;
    uint256 internal constant MINT_FEE_RATE = 1e15;
    uint96 private stakeAmount = (100 * UNIT).toUint96();

    address staker = MEMBER;
    address borrower = ACCOUNT;

    function setUp() public virtual {
        address userManagerLogic = address(new UserManager());
        address uTokenLogic = address(new UToken());
        deployMocks();
        uToken = UToken(
            deployProxy(
                uTokenLogic,
                abi.encodeWithSignature(
                    "__UToken_init((string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,uint256))",
                    UToken.InitParams({
                        name: "UTokenMock",
                        symbol: "UTM",
                        underlying: address(erc20Mock),
                        initialExchangeRateMantissa: INIT_EXCHANGE_RATE,
                        reserveFactorMantissa: RESERVE_FACTOR,
                        originationFee: ORIGINATION_FEE,
                        originationFeeMax: ORIGINATION_FEE_MAX,
                        debtCeiling: 1000 * UNIT,
                        maxBorrow: MAX_BORROW,
                        minBorrow: MIN_BORROW,
                        overdueTime: OVERDUE_TIME,
                        admin: ADMIN,
                        mintFeeRate: MINT_FEE_RATE
                    })
                )
            )
        );
        userManager = UserManager(
            deployProxy(
                userManagerLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                    address(assetManagerMock),
                    address(unionTokenMock),
                    address(erc20Mock),
                    address(comptrollerMock),
                    ADMIN,
                    1000,
                    3,
                    500,
                    1000
                )
            )
        );
        vm.startPrank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(userManager));
        userManager.setUToken(address(uToken));
        userManager.addMember(staker);
        userManager.addMember(borrower);
        uToken.setUserManager(address(userManager));
        uToken.setAssetManager(address(assetManagerMock));
        uToken.setInterestRateModel(address(interestRateMock));
        vm.stopPrank();
        erc20Mock.mint(staker, stakeAmount);
        erc20Mock.mint(borrower, stakeAmount);
        erc20Mock.mint(address(assetManagerMock), 100 * UNIT);

        vm.startPrank(staker);
        erc20Mock.approve(address(userManager), type(uint256).max);
        userManager.stake(stakeAmount);
        userManager.updateTrust(borrower, stakeAmount);
        vm.stopPrank();
    }

    function testRepayBorrowWhenOverdue(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - ((MAX_BORROW * ORIGINATION_FEE) / 1e18));
        vm.startPrank(borrower);
        uToken.borrow(borrower, borrowAmount);
        // fast forward to overdue time
        skip(block.timestamp + OVERDUE_TIME + 10);
        assertTrue(uToken.checkIsOverdue(borrower));
        uint256 borrowed = uToken.borrowBalanceView(borrower);
        uint256 interest = uToken.calculatingInterest(borrower);
        uint256 locked = userManager.getLockedStake(staker, borrower);
        uint256 repayAmount = borrowed + interest;
        assertEq(userManager.frozenCoinAge(staker), 0);
        erc20Mock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(borrower, repayAmount);
        vm.stopPrank();
        assertTrue(!uToken.checkIsOverdue(borrower));
        assertEq(0, uToken.borrowBalanceView(borrower));
        uint256 expectFrozenCoinAge = locked * 11; //Default time 1 block
        assertEq(userManager.frozenCoinAge(staker), expectFrozenCoinAge);
    }
}
