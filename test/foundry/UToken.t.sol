pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {UToken} from "union-v1.5-contracts/market/UToken.sol";

contract TestUToken is TestWrapper {
    UToken public uToken;
    address public constant ADMIN = address(1);
    address public constant ALICE = address(2);
    address public constant BOB = address(3);

    uint256 internal constant ORIGINATION_FEE = 0.01 ether;
    uint256 internal constant MIN_BORROW = 1 ether;
    uint256 internal constant MAX_BORROW = 100 ether;
    uint256 internal constant BORROW_INTEREST_PER_BLOCK = 0.000001 ether; //0.0001%
    uint256 internal constant OVERDUE_BLOCKS = 10;

    function setUp() public virtual {
        uint256 initialExchangeRateMantissa = 1 ether;
        uint256 reserveFactorMantissa = 0.5 ether;
        uint256 debtCeiling = 1000 ether;
        address uTokenLogic = address(new UToken());

        deployMocks();

        uToken = UToken(
            deployProxy(
                uTokenLogic,
                abi.encodeWithSignature(
                    "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
                    "UTokenMock",
                    "UTM",
                    address(daiMock),
                    initialExchangeRateMantissa,
                    reserveFactorMantissa,
                    ORIGINATION_FEE,
                    debtCeiling,
                    MAX_BORROW,
                    MIN_BORROW,
                    OVERDUE_BLOCKS,
                    ADMIN
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

    function testSetAssetManager(address assetManager) public {
        vm.assume(assetManager != address(0));
        vm.startPrank(ADMIN);
        uToken.setAssetManager(assetManager);
        vm.stopPrank();

        address uTokenAssetMgr = uToken.assetManager();
        assertEq(uTokenAssetMgr, assetManager);
    }

    function testSupplyRate() public {
        uint256 reserveFactorMantissa = uToken.reserveFactorMantissa();
        uint256 expectSupplyRate = (BORROW_INTEREST_PER_BLOCK * (1 ether - reserveFactorMantissa)) / 1 ether;
        assertEq(expectSupplyRate, uToken.supplyRatePerBlock());
    }

    function testCannotBorrowNonMember() public {
        userManagerMock.setIsMember(false);

        vm.expectRevert(UToken.CallerNotMember.selector);
        uToken.borrow(1 ether);
    }

    function testBorrowFeeAndInterest(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);
        uToken.borrow(borrowAmount);
        vm.stopPrank();

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        // borrowed amount should only include origination fee
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1 ether);

        // advance 1 more block
        vm.roll(block.number + 1);

        // borrowed amount should now include interest
        uint256 interest = uToken.calculatingInterest(ALICE);
        assertEq(uToken.borrowBalanceView(ALICE), borrowed + interest);
    }

    function testRepayBorrow() public {
        vm.startPrank(ALICE);

        uToken.borrow(1 ether);

        uint256 initialBorrow = uToken.borrowBalanceView(ALICE);
        assertEq(initialBorrow, 1 ether + ORIGINATION_FEE);

        vm.roll(block.number + 1);

        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);

        uint256 repayAmount = initialBorrow + interest;

        daiMock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(repayAmount);

        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowWhenOverdue() public {
        vm.startPrank(ALICE);

        uToken.borrow(1 ether);

        // fast forward to overdue block
        vm.roll(block.number + OVERDUE_BLOCKS + 1);

        assertTrue(uToken.checkIsOverdue(ALICE));

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        daiMock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(repayAmount);

        vm.stopPrank();

        assertTrue(!uToken.checkIsOverdue(ALICE));

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowOnBehalf() public {
        // Alice borrows first
        vm.startPrank(ALICE);

        uToken.borrow(1 ether);

        vm.stopPrank();

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;

        // Bob repay on behalf of Alice
        vm.startPrank(BOB);

        daiMock.approve(address(uToken), repayAmount);
        uToken.repayBorrowBehalf(ALICE, repayAmount);

        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testMintUToken() public {}

    function testRedeemUToken() public {}

    function testRedeemUnderlying() public {}

    function testAddReserve() public {}

    function testRemoveReserve() public {}

    function testUpdateOverdue() public {}

    function testBatchUpdateOverdue() public {}
}
