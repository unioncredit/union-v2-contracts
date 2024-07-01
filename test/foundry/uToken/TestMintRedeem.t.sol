pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestMintRedeem is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function nearlyEqual(uint256 a, uint256 b, uint256 eps) private pure returns (bool) {
        return (a >= b && a - b <= eps) || (b > a && b - a <= eps);
    }

    function testSupplyRate() public {
        uint256 reserveFactorMantissa = uToken.reserveFactorMantissa();
        uint256 expectSupplyRate = (BORROW_INTEREST_PER_BLOCK * (1e18 - reserveFactorMantissa)) / 1e18;

        assertEq(expectSupplyRate, uToken.supplyRatePerSecond());
    }

    function testMintUTokenWithMintFee(uint256 mintAmount, uint256 mintFeeRate) public {
        vm.assume(mintAmount > UNIT && mintAmount <= 100 * UNIT);
        mintFeeRate = bound(mintFeeRate, 0, 1e17);
        require(mintFeeRate >= 0 && mintFeeRate <= 1e17);

        vm.startPrank(ADMIN);
        uToken.setMintFeeRate(mintFeeRate);
        vm.stopPrank();

        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);

        uint256 mintFee = (mintAmount * mintFeeRate) / 1e18;
        uint256 redeemable = mintAmount - mintFee;
        uint256 totalRedeemable = uToken.totalRedeemable();

        nearlyEqual(redeemable, totalRedeemable, 100);

        uint256 balance = uToken.balanceOf(ALICE);
        uint256 totalSupply = uToken.totalSupply();
        nearlyEqual(balance, totalSupply, 100);

        uint256 currExchangeRate = uToken.exchangeRateStored();
        nearlyEqual(balance, (redeemable * 1e18) / currExchangeRate, 100);
    }

    function testMintUTokenFailWithMinAmount(uint256 mintAmount) public {
        vm.assume(mintAmount < uToken.minMintAmount());

        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), mintAmount);
        vm.expectRevert(UToken.AmountError.selector);
        uToken.mint(mintAmount);
    }

    function testRedeemUToken(uint256 mintAmount) public {
        vm.assume(mintAmount >= uToken.minMintAmount() && mintAmount <= 100 * UNIT);
        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);
        uint256 exchangeRateStored = uToken.exchangeRateStored();
        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 ercBalance = erc20Mock.balanceOf(ALICE);
        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;
        uint256 redeemable = mintAmount - mintFee;
        assertEq(uBalance, ((redeemable * 1e18) / exchangeRateStored));

        uToken.redeem(uBalance, 0);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 ercBalanceAfter = erc20Mock.balanceOf(ALICE);
        nearlyEqual(ercBalanceAfter, ercBalance + mintAmount - mintFee, 100);
    }

    function testRedeemUTokenWhenRemaining(uint256 mintAmount) public {
        vm.assume(mintAmount > 1 * UNIT + uToken.minMintAmount() && mintAmount <= 100 * UNIT);

        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);
        uint256 exchangeRateStored = uToken.exchangeRateStored();

        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;
        uint256 totalRedeemable = uToken.totalRedeemable();
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, erc20Mock, ALICE, mintAmount - mintFee),
            abi.encode(1 * UNIT)
        );
        uToken.redeem(((mintAmount - mintFee) * 1e18) / exchangeRateStored, 0);
        uint256 totalRedeemableAfter = uToken.totalRedeemable();

        assertEq(totalRedeemableAfter, totalRedeemable + mintFee - mintAmount + 1 * UNIT);
    }

    function testRedeemUnderlying(uint256 mintAmount) public {
        vm.assume(mintAmount > uToken.minMintAmount() && mintAmount <= 100 * UNIT);

        vm.startPrank(ALICE);

        erc20Mock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);
        uint256 exchangeRateStored = uToken.exchangeRateStored();
        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;

        uint256 uBalance = uToken.balanceOf(ALICE);
        uint256 erc20Balance = erc20Mock.balanceOf(ALICE);
        assertEq(uBalance, ((mintAmount - mintFee) * 1e18) / exchangeRateStored);

        uToken.redeem(0, mintAmount - mintFee);
        uBalance = uToken.balanceOf(ALICE);
        assertEq(0, uBalance);

        uint256 daiBalanceAfter = erc20Mock.balanceOf(ALICE);
        nearlyEqual(daiBalanceAfter, erc20Balance + mintAmount - mintFee, 100);
    }

    function testExchangeRate() public {
        uint256 mintAmount = 1 * UNIT;
        uint256 borrowAmount = 1 * UNIT;
        assertEq(INIT_EXCHANGE_RATE, uToken.exchangeRateCurrent());
        vm.startPrank(ALICE);
        erc20Mock.approve(address(uToken), mintAmount);
        uToken.mint(mintAmount);
        uint256 utokenBal = uToken.balanceOf(ALICE);

        uint256 exchangeRateStored = uToken.exchangeRateStored();
        assertEq((utokenBal * exchangeRateStored) / 1e18, uToken.balanceOfUnderlying(ALICE));

        uToken.borrow(ALICE, borrowAmount);
        uint256 borrowed = uToken.borrowBalanceView(ALICE);
        skip(block.timestamp + 1);
        // Get the interest amount
        uint256 interest = uToken.calculatingInterest(ALICE);
        uint256 repayAmount = borrowed + interest;
        erc20Mock.approve(address(uToken), repayAmount);
        uToken.repayBorrow(ALICE, repayAmount);
        assert(uToken.exchangeRateCurrent() > INIT_EXCHANGE_RATE);
        assert((utokenBal * exchangeRateStored) / 1e18 < uToken.balanceOfUnderlying(ALICE));
    }
}
