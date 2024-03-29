pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestUTokenBase is TestWrapper {
    UToken public uToken;
    address public constant ADMIN = address(1);
    address public constant ALICE = address(2);
    address public constant BOB = address(3);

    uint256 internal constant ORIGINATION_FEE = 0.01 ether;
    uint256 internal constant ORIGINATION_FEE_MAX = 0.05 ether;
    uint256 internal constant MIN_BORROW = 1 ether;
    uint256 internal constant MAX_BORROW = 100 ether;
    uint256 internal constant BORROW_INTEREST_PER_BLOCK = 0.000001 ether; //0.0001%
    uint256 internal constant OVERDUE_TIME = 10; // seconds
    uint256 internal constant RESERVE_FACTOR = 0.5 ether;
    uint256 internal constant INIT_EXCHANGE_RATE = 1 ether;
    uint256 internal constant MINT_FEE_RATE = 1e15;

    function setUp() public virtual {
        uint256 debtCeiling = 1000 ether;
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
                        underlying: address(daiMock),
                        initialExchangeRateMantissa: INIT_EXCHANGE_RATE,
                        reserveFactorMantissa: RESERVE_FACTOR,
                        originationFee: ORIGINATION_FEE,
                        originationFeeMax: ORIGINATION_FEE_MAX,
                        debtCeiling: debtCeiling,
                        maxBorrow: MAX_BORROW,
                        minBorrow: MIN_BORROW,
                        overdueTime: OVERDUE_TIME,
                        admin: ADMIN,
                        mintFeeRate: MINT_FEE_RATE
                    })
                )
            )
        );

        vm.startPrank(ADMIN);
        uToken.setUserManager(address(userManagerMock));
        uToken.setAssetManager(address(assetManagerMock));
        uToken.setInterestRateModel(address(interestRateMock));
        vm.stopPrank();

        daiMock.mint(address(assetManagerMock), 100 ether);
        daiMock.mint(ALICE, 100 ether);
        daiMock.mint(BOB, 100 ether);

        userManagerMock.setIsMember(true);
    }
}
