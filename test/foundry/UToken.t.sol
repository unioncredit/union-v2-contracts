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
    uint256 internal constant RESERVE_FACTOR = 0.5 ether;
    uint256 internal constant INIT_EXCHANGE_RATE = 1 ether;

    function setUp() public virtual {
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
                    INIT_EXCHANGE_RATE,
                    RESERVE_FACTOR,
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
        uint256 fees = (ORIGINATION_FEE * borrowAmount) / 1 ether;
        assertEq(borrowed, borrowAmount + fees);

        // advance 1 more block
        vm.roll(block.number + 1);

        // borrowed amount should now include interest
        uint256 interest = ((borrowAmount + fees) * BORROW_INTEREST_PER_BLOCK) / 1 ether;

        assertEq(uToken.borrowBalanceView(ALICE), borrowed + interest);
    }

    function testRepayBorrow(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(borrowAmount);

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        assertEq(borrowed, borrowAmount + (ORIGINATION_FEE * borrowAmount) / 1 ether);

        vm.roll(block.number + 1);

        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);

        uint256 repayAmount = borrowed + interest;

        daiMock.approve(address(uToken), repayAmount);

        uToken.repayBorrow(repayAmount);

        vm.stopPrank();

        assertEq(0, uToken.borrowBalanceView(ALICE));
    }

    function testRepayBorrowWhenOverdue(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        vm.startPrank(ALICE);

        uToken.borrow(borrowAmount);

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

    function testRepayBorrowOnBehalf(uint256 borrowAmount) public {
        vm.assume(borrowAmount >= MIN_BORROW && borrowAmount < MAX_BORROW - (MAX_BORROW * ORIGINATION_FEE) / 1 ether);

        // Alice borrows first
        vm.startPrank(ALICE);

        uToken.borrow(borrowAmount);

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

    function testMintUToken(uint256 mintAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= 100 ether);

        assertEq(INIT_EXCHANGE_RATE, uToken.exchangeRateStored());

        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 totalRedeemable = uToken.totalRedeemable();
        assertEq(mintAmount, totalRedeemable);

        uint256 balance = uToken.balanceOf(ALICE);
        uint256 totalSupply = uToken.totalSupply();
        assertEq(balance, totalSupply);

        uint256 currExchangeRate = uToken.exchangeRateStored();
        assertEq(balance, (mintAmount * 1 ether) / currExchangeRate);
    }

    function testRedeemUToken(uint256 mintAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= 100 ether);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 daiBalance = daiMock.balanceOf(ALICE);

        assertEq(uBalance, mintAmount);

        uToken.redeem(uBalance);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalance + mintAmount);
    }

    function testRedeemUnderlying(uint256 mintAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= 100 ether);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 daiBalance = daiMock.balanceOf(ALICE);

        assertEq(uBalance, mintAmount);

        uToken.redeemUnderlying(mintAmount);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalance + mintAmount);
    }

    function testAddAndRemoveReserve(uint256 addReserveAmount) public {
        vm.assume(addReserveAmount > 0 && addReserveAmount <= 100 ether);

        uint256 totalReserves = uToken.totalReserves();
        assertEq(0, totalReserves);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), addReserveAmount);
        uToken.addReserves(addReserveAmount);

        vm.stopPrank();

        totalReserves = uToken.totalReserves();
        assertEq(totalReserves, addReserveAmount);

        uint256 daiBalanceBefore = daiMock.balanceOf(ALICE);

        vm.startPrank(ADMIN);

        uToken.removeReserves(ALICE, addReserveAmount);
        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalanceBefore + addReserveAmount);
    }
}
