import {expect} from "chai";
import {BigNumber, Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Minting and redeeming uToken", () => {
    let signers: Signer[];
    let deployer: Signer;
    let user: Signer;
    let deployerAddress: string;
    let userAddress: string;
    let contracts: Contracts;
    let assetManagerAddress: string;
    let WAD: BigNumber;

    const mintAmount = parseUnits("1000");

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        user = signers[1];
        deployerAddress = await deployer.getAddress();
        userAddress = await user.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
        assetManagerAddress = await contracts.uToken.assetManager();
        WAD = await contracts.uToken.WAD();
        await contracts.userManager.addMember(deployerAddress);
        await contracts.userManager.addMember(userAddress);
        await contracts.userManager.setEffectiveCount(1);

        if ("mint" in contracts.dai) {
            const amount = parseUnits("1000000");
            const stakeAmount = parseUnits("1000");
            await contracts.dai.mint(deployerAddress, amount);
            await contracts.dai.approve(contracts.uToken.address, amount);

            await contracts.dai.approve(contracts.userManager.address, stakeAmount);
            await contracts.userManager.stake(stakeAmount);
            await contracts.userManager.updateTrust(userAddress, stakeAmount);
        }
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

            await contracts.uToken.redeemUnderlying(mintAmount);

            const balanceAfter = await contracts.dai.balanceOf(deployerAddress);
            const assetManagerBalAfter = await contracts.dai.balanceOf(assetManagerAddress);

            expect(balanceAfter.sub(balanceBefore)).eq(mintAmount);
            expect(assetManagerBalBefore.sub(assetManagerBalAfter)).eq(mintAmount);
        });
        it("mint when exchangeRate change", async () => {
            await contracts.fixedInterestRateModel.setInterestRate("10000000000000"); //0.001e16 = 0.001% per block
            //In order to facilitate the calculation, remove the interference
            await contracts.uToken.setReserveFactor(0);
            await contracts.uToken.setOriginationFee(0);
            const mintAmount = parseUnits("100");
            await contracts.uToken.mint(mintAmount);
            let uTokenBal = await contracts.uToken.balanceOf(deployerAddress);
            expect(uTokenBal).eq(mintAmount);

            const borrowAmount = parseUnits("100");
            await contracts.uToken.connect(user).borrow(borrowAmount);
            await contracts.uToken.repayBorrowBehalf(userAddress, borrowAmount);

            let exchangeRateStored = await contracts.uToken.exchangeRateStored();
            const expectRate = ((100 + 100 * 0.00001) / 100) * 1e18; //(mint use dai amount + repay interest) / uDai amount
            expect(((parseFloat(exchangeRateStored.toString()) + 100) / 10000).toFixed(0)).eq(
                ((expectRate + 100) / 10000).toFixed(0)
            );

            await contracts.uToken.mint(mintAmount);
            uTokenBal = await contracts.uToken.balanceOf(deployerAddress);
            const expectUDaiBal = mintAmount.add(mintAmount.mul(WAD).div(exchangeRateStored));
            expect(uTokenBal).eq(expectUDaiBal);
        });
    });
});
