import "./testSetup";

import {expect} from "chai";
import {BigNumber, Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import error from "../utils/error";
import {isForked} from "../utils/fork";
import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {fork, roll, getDai, getDeployer, getSigners} from "../utils";

describe("Minting and redeeming uToken", () => {
    let deployer: Signer;
    let user: Signer;
    let deployerAddress: string;
    let userAddress: string;
    let contracts: Contracts;
    let assetManagerAddress: string;
    let WAD: BigNumber;

    const mintAmount = parseUnits("1000");

    const beforeContext = async () => {
        if(isForked()) await fork();

        const signers = await getSigners();
        deployer = await getDeployer();

        user = signers[1];

        deployerAddress = await deployer.getAddress();
        userAddress = await user.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        assetManagerAddress = await contracts.uToken.assetManager();
        WAD = await contracts.uToken.WAD();
        await contracts.userManager.addMember(deployerAddress);
        await contracts.userManager.addMember(userAddress);
        await contracts.userManager.setEffectiveCount(1);

        const amount = parseUnits("10000");
        const stakeAmount = parseUnits("1000");
        await getDai(contracts.dai, deployer, amount);
        await contracts.dai.approve(contracts.uToken.address, amount);

        await contracts.dai.approve(contracts.userManager.address, stakeAmount);
        await contracts.userManager.stake(stakeAmount);
        await contracts.userManager.updateTrust(userAddress, stakeAmount);
    };

    context("Minting uToken", () => {
        before(beforeContext);
        it("can mint and recieve uDAI", async () => {
            const exchangeRateStored = await contracts.uToken.exchangeRateStored();

            const balanceBefore = await contracts.uToken.balanceOf(deployerAddress);
            const assetManagerBalBefore = await contracts.dai.balanceOf(assetManagerAddress);

            await contracts.uToken.mint(mintAmount);

            const balanceAfter = await contracts.uToken.balanceOf(deployerAddress);
            const assetManagerBalAfter = await contracts.dai.balanceOf(assetManagerAddress);

            expect(balanceAfter.sub(balanceBefore)).eq(mintAmount.mul(WAD).div(exchangeRateStored));
            expect(assetManagerBalAfter.sub(assetManagerBalBefore)).eq(mintAmount);
        });
        it("can redeem uDAI for DAI", async () => {
            const balanceBefore = await contracts.dai.balanceOf(deployerAddress);
            const assetManagerBalBefore = await contracts.dai.balanceOf(assetManagerAddress);

            await contracts.uToken.redeem(0, mintAmount);

            const balanceAfter = await contracts.dai.balanceOf(deployerAddress);
            const assetManagerBalAfter = await contracts.dai.balanceOf(assetManagerAddress);

            expect(balanceAfter.sub(balanceBefore)).eq(mintAmount);
            expect(assetManagerBalBefore.sub(assetManagerBalAfter)).eq(mintAmount);
        });
        it("mint when exchangeRate change", async () => {
            //exchangeRate does not change at 100%
            await contracts.uToken.setReserveFactor("50"); //50%
            const interestRatePerBlock = await contracts.fixedInterestRateModel.interestRatePerBlock();
            const reserveFactorMantissa = await contracts.uToken.reserveFactorMantissa();
            const originationFee = await contracts.uToken.originationFee();
            const mintAmount = parseUnits("100");
            await contracts.uToken.mint(mintAmount);
            let uTokenBal = await contracts.uToken.balanceOf(deployerAddress);
            expect(uTokenBal).eq(mintAmount);

            const borrowAmount = parseUnits("100");
            await contracts.uToken.connect(user).borrow(userAddress, borrowAmount);
            const blocks = 99;
            await roll(blocks);
            await contracts.uToken.repayBorrow(userAddress, borrowAmount);

            let exchangeRateStored = await contracts.uToken.exchangeRateStored();
            const expeOriginationFee = borrowAmount.mul(originationFee).div(WAD);
            const expectInterest = borrowAmount
                .mul(interestRatePerBlock)
                .mul(BigNumber.from(blocks + 1))
                .div(WAD);
            const expectRedeemable = expectInterest
                .add(
                    expeOriginationFee
                        .mul(interestRatePerBlock)
                        .mul(BigNumber.from(blocks + 1))
                        .div(WAD)
                )
                .sub(expectInterest.mul(reserveFactorMantissa).div(WAD));
            const expectRate = mintAmount.add(expectRedeemable).mul(WAD).div(mintAmount);
            expect(exchangeRateStored.add(100).div(10000)).eq(expectRate.add(100).div(10000));

            await contracts.uToken.mint(mintAmount);
            uTokenBal = await contracts.uToken.balanceOf(deployerAddress);
            const expectUDaiBal = mintAmount.add(mintAmount.mul(WAD).div(exchangeRateStored));
            expect(uTokenBal).eq(expectUDaiBal);
        });
    });
});
