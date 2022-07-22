pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {UToken} from "union-v1.5-contracts/market/UToken.sol";

contract TestUToken is TestWrapper {
    UToken public uToken;
    address public constant ADMIN = address(1);
    address public constant ALICE = address(2);
    address public constant BOB = address(3);

    uint256 internal constant originationFee = 0.01 ether;
    uint256 borrowInterestPerBlock = 0.000001 ether; //0.0001%

    function setUp() public virtual {
        uint256 initialExchangeRateMantissa = 1 ether;
        uint256 reserveFactorMantissa = 0.5 ether;
        uint256 debtCeiling = 1000 ether;
        uint256 maxBorrow = 100 ether;
        uint256 minBorrow = 1 ether;
        uint256 overdueBlocks = 10;
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
                    originationFee,
                    debtCeiling,
                    maxBorrow,
                    minBorrow,
                    overdueBlocks,
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

    function testGetAssetManager(address assetManager) public {
        // vm.assume(assetManager != address(0));
        address uTokenAssetMgr = uToken.assetManager();
        assertEq(uTokenAssetMgr, address(assetManagerMock));
    }

    function testSupplyRate() public {
        uint256 reserveFactorMantissa = uToken.reserveFactorMantissa();
        uint256 expectSupplyRate = (borrowInterestPerBlock * (1 ether - reserveFactorMantissa)) / 1 ether;
        assertEq(expectSupplyRate, uToken.supplyRatePerBlock());
    }

    function testCannotBorrowNonMember() public {
        userManagerMock.setIsMember(false);

        vm.expectRevert(UToken.CallerNotMember.selector);
        uToken.borrow(1 ether);
    }

    function testBorrowFeeAndInterest() public {
        vm.startPrank(ALICE);
        uToken.borrow(1 ether);
        vm.stopPrank();

        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        // borrowed amount should only include origination fee
        assertEq(borrowed, 1 ether + originationFee);

        // advance 1 more block
        vm.roll(block.number + 1);

        // borrowed amount should now include interest
        assertEq(uToken.borrowBalanceView(ALICE), borrowed + (borrowed * borrowInterestPerBlock) / 1 ether);
    }

    function testRepayBorrow() public {
        vm.startPrank(ALICE);

        uToken.borrow(1 ether);

        uint256 initialBorrow = uToken.borrowBalanceView(ALICE);
        assertEq(initialBorrow, 1 ether + originationFee);

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

        uint256 overdueBlocks = uToken.overdueBlocks();
        // fast forward to overdue block
        vm.roll(block.number + overdueBlocks + 1);

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
