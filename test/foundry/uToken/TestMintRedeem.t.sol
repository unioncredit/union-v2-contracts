pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v1.5-contracts/market/UToken.sol";

contract TestMintRedeem is TestUTokenBase {

    function setUp() public override {
        super.setUp();
    }

    function testSupplyRate() public {
        uint256 reserveFactorMantissa = uToken.reserveFactorMantissa();
        uint256 expectSupplyRate = (BORROW_INTEREST_PER_BLOCK * (1 ether - reserveFactorMantissa)) / 1 ether;
        assertEq(expectSupplyRate, uToken.supplyRatePerBlock());
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
}
