pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestMintRedeem is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function testSupplyRate() public {
        uint256 reserveFactorMantissa = uToken.reserveFactorMantissa();
        uint256 expectSupplyRate = (BORROW_INTEREST_PER_BLOCK * (1 ether - reserveFactorMantissa)) / 1 ether;
        assertEq(expectSupplyRate, uToken.supplyRatePerBlock());
    }

    function testMintUTokenWithMintFee(uint256 mintAmount, uint256 mintFeeRate) public {
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT() && mintAmount <= 100 ether);
        vm.assume(mintFeeRate >= 0 && mintFeeRate <= 1e17);

        vm.startPrank(ADMIN);
        uToken.setMintFeeRate(mintFeeRate);
        vm.stopPrank();

        assertEq(INIT_EXCHANGE_RATE, uToken.exchangeRateStored());

        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 mintFee = (mintAmount * mintFeeRate) / 1e18;
        uint256 redeemable = mintAmount - mintFee;
        uint256 totalRedeemable = uToken.totalRedeemable();

        assertEq(redeemable, totalRedeemable);

        uint256 balance = uToken.balanceOf(ALICE);
        uint256 totalSupply = uToken.totalSupply();
        assertEq(balance, totalSupply);

        uint256 currExchangeRate = uToken.exchangeRateStored();
        assertEq(balance, (redeemable * 1e18) / currExchangeRate);
    }

    function testMintUTokenFailWithMinAmount(uint256 mintAmount) public {
        vm.assume(mintAmount < uToken.MIN_MINT_AMOUNT());

        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), mintAmount);
        vm.expectRevert(UToken.AmountError.selector);
        uToken.mint(mintAmount);
    }

    function testRedeemUToken(uint256 mintAmount) public {
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT() && mintAmount <= 100 ether);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 daiBalance = daiMock.balanceOf(ALICE);

        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;
        uint256 redeemable = mintAmount - mintFee;

        assertEq(uBalance, redeemable);

        uToken.redeem(uBalance, 0);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalance + mintAmount - mintFee);
    }

    function testRedeemUTokenWhenRemaining(uint256 mintAmount) public {
        vm.assume(mintAmount > 1 ether + uToken.MIN_MINT_AMOUNT() && mintAmount <= 100 ether);

        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;

        uint256 totalRedeemable = uToken.totalRedeemable();
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, daiMock, ALICE, mintAmount - mintFee),
            abi.encode(1 ether)
        );
        uToken.redeem(mintAmount - mintFee, 0);
        uint256 totalRedeemableAfter = uToken.totalRedeemable();
        assertEq(totalRedeemableAfter, totalRedeemable + mintFee - mintAmount + 1 ether);
    }

    function testRedeemUnderlying(uint256 mintAmount) public {
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT() && mintAmount <= 100 ether);

        vm.startPrank(ALICE);

        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;

        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 daiBalance = daiMock.balanceOf(ALICE);

        assertEq(uBalance, mintAmount - mintFee);

        uToken.redeem(0, mintAmount - mintFee);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 daiBalanceAfter = daiMock.balanceOf(ALICE);
        assertEq(daiBalanceAfter, daiBalance + mintAmount - mintFee);
    }

    function testExchangeRate() public {
        uint256 mintAmount = 1 ether;
        uint256 borrowAmount = 1 ether;
        assertEq(INIT_EXCHANGE_RATE, uToken.exchangeRateCurrent());
        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 utokenBal = uToken.balanceOf(ALICE);
        assertEq((utokenBal * INIT_EXCHANGE_RATE) / 1e18, uToken.balanceOfUnderlying(ALICE));

        uToken.borrow(ALICE, borrowAmount);
        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        skip(block.timestamp + 1);
        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;
        daiMock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);
        assert(uToken.exchangeRateCurrent() > INIT_EXCHANGE_RATE);
        assert((utokenBal * INIT_EXCHANGE_RATE) / 1e18 < uToken.balanceOfUnderlying(ALICE));
    }
}
