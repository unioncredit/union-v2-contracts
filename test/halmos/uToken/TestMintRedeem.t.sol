pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestMintRedeem is TestUTokenBase {
    function setUp() public override {
        super.setUp();
        vm.startPrank(ALICE);
        daiMock.approve(address(uToken), type(uint256).max);
        vm.stopPrank();
    }

    function testMintUTokenWithMintFee() public {
        uint256 mintAmount = svm.createUint256("mintAmount");
        uint256 mintFeeRate = svm.createUint256("mintFeeRate");
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT() && mintAmount <= 100 ether);
        vm.assume(mintFeeRate >= 0 && mintFeeRate <= 1e17);

        vm.startPrank(ADMIN);
        uToken.setMintFeeRate(mintFeeRate);
        vm.stopPrank();

        vm.startPrank(ALICE);
        uToken.mint(mintAmount);
        vm.stopPrank();
    }

    function testRedeemUToken() public {
        uint256 mintAmount = svm.createUint256("mintAmount");
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT());

        vm.startPrank(ALICE);
        uToken.mint(mintAmount);

        uint256 uBalance = uToken.balanceOf(ALICE);

        uToken.redeem(uBalance, 0);
        vm.stopPrank();
    }

    function testRedeemUnderlying() public {
        uint256 mintAmount = svm.createUint256("mintAmount");
        vm.assume(mintAmount > uToken.MIN_MINT_AMOUNT());

        vm.startPrank(ALICE);
        uToken.mint(mintAmount);

        uint256 mintFee = (mintAmount * MINT_FEE_RATE) / 1e18;

        uToken.redeem(0, mintAmount - mintFee);
        vm.stopPrank();
    }
}
