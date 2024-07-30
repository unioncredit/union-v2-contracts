pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {UDai} from "union-v2-contracts/market/UDai.sol";
import {UErc20} from "union-v2-contracts/market/UErc20.sol";
import {console} from "forge-std/console.sol";
contract TestPermit is TestUTokenBase {
    UDai public uDai;
    UErc20 public uErc20;

    function setUp() public override {
        super.setUp();
        uDai = UDai(
            deployProxy(
                address(new UDai()),
                abi.encodeWithSignature(
                    "__UToken_init((string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,uint256))",
                    UToken.InitParams({
                        name: "UDaiMock",
                        symbol: "UDM",
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
        uErc20 = UErc20(
            deployProxy(
                address(new UErc20()),
                abi.encodeWithSignature(
                    "__UToken_init((string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,uint256))",
                    UToken.InitParams({
                        name: "UErcMock",
                        symbol: "UEM",
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
        vm.startPrank(ADMIN);
        uDai.setUserManager(address(userManagerMock));
        uDai.setAssetManager(address(assetManagerMock));
        uDai.setInterestRateModel(address(interestRateMock));
        uErc20.setUserManager(address(userManagerMock));
        uErc20.setAssetManager(address(assetManagerMock));
        uErc20.setInterestRateModel(address(interestRateMock));
        vm.stopPrank();
    }

    function testRepayBorrowWithPermit(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);

        vm.startPrank(ALICE);

        uDai.borrow(ALICE, borrowAmount);

        uint256 borrowed = uDai.borrowBalanceView(ALICE);
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1e18);

        skip(block.timestamp + 1);

        // Get the interest amount
        uint256 interest = uDai.calculatingInterest(ALICE);

        uint256 repayAmount = borrowed + interest + 100; //prevent dust

        uint8 v;
        bytes32 r;
        bytes32 s;
        uDai.repayBorrowWithPermit(ALICE, repayAmount, 0, 0, v, r, s);
        vm.stopPrank();
        assertEq(0, uDai.borrowBalanceView(ALICE));
    }

    function testRepayBorrowWithERC20Permit(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1e18);
        vm.startPrank(ALICE);

        uErc20.borrow(ALICE, borrowAmount);

        uint256 borrowed = uErc20.borrowBalanceView(ALICE);
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1e18);

        skip(block.timestamp + 1);

        // Get the interest amount
        uint256 interest = uErc20.calculatingInterest(ALICE);

        uint256 repayAmount = borrowed + interest + 100; //prevent dust

        uint8 v;
        bytes32 r;
        bytes32 s;
        uErc20.repayBorrowWithERC20Permit(ALICE, repayAmount, block.timestamp, v, r, s);

        vm.stopPrank();
        assertEq(0, uErc20.borrowBalanceView(ALICE));
    }
}
