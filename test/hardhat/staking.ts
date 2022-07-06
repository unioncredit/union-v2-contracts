import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import {roll} from "../utils";
import config from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";

describe("Staking and unstaking", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);

        if ("mint" in contracts.dai) {
            for (const signer of signers) {
                const address = await signer.getAddress();
                const amount = parseUnits("10000000");
                await contracts.dai.mint(address, amount);
                await contracts.dai.connect(signer).approve(contracts.userManager.address, amount);
            }
        }
    };

    context("staking and unstaking as a non member", () => {
        before(beforeContext);
        it("cannot stake more than limit", async () => {
            const maxStake = await contracts.userManager.maxStakeAmount();
            await expect(contracts.userManager.stake(maxStake.add(1))).to.be.revertedWith("StakeLimitReached()");
        });
        it("transfers underlying token to assetManager", async () => {
            const stakeAmount = parseUnits("100");
            const assetManagerBalanceBefore = await contracts.assetManager.getPoolBalance(contracts.dai.address);
            const totalStakedBefore = await contracts.userManager.totalStaked();
            await contracts.userManager.stake(stakeAmount);
            const totalStakedAfter = await contracts.userManager.totalStaked();
            const assetManagerBalanceAfter = await contracts.assetManager.getPoolBalance(contracts.dai.address);

            expect(totalStakedAfter.sub(totalStakedBefore)).eq(stakeAmount);
            expect(assetManagerBalanceAfter.sub(assetManagerBalanceBefore)).eq(stakeAmount);
        });
        it("cannot unstake more than staked", async () => {
            const stakeAmount = await contracts.userManager.getStakerBalance(deployerAddress);
            const resp = contracts.userManager.unstake(stakeAmount.add(1));
            await expect(resp).to.be.revertedWith("InsufficientBalance()");
        });
        it("unstaking transfers underlying token from assetManager", async () => {
            const stakeAmount = await contracts.userManager.getStakerBalance(deployerAddress);
            const assetManagerBalanceBefore = await contracts.assetManager.getPoolBalance(contracts.dai.address);
            const totalStakedBefore = await contracts.userManager.totalStaked();
            await contracts.userManager.unstake(stakeAmount);
            const totalStakedAfter = await contracts.userManager.totalStaked();
            const assetManagerBalanceAfter = await contracts.assetManager.getPoolBalance(contracts.dai.address);

            expect(totalStakedBefore.sub(totalStakedAfter)).eq(stakeAmount);
            expect(assetManagerBalanceBefore.sub(assetManagerBalanceAfter)).eq(stakeAmount);
        });
    });

    context("staking rewards", () => {
        before(async () => {
            await beforeContext();
            if ("mint" in contracts.dai) {
                const amount = parseUnits("1000000");
                await contracts.unionToken.mint(contracts.comptroller.address, amount);
            }
        });
        it("stake", async () => {
            const stakeAmount = parseUnits("100");
            await contracts.userManager.stake(stakeAmount);
        });
        it("withdraw rewards from comptroller", async () => {
            await roll(10);
            const rewards = await contracts.comptroller.calculateRewardsByBlocks(
                deployerAddress,
                contracts.dai.address,
                1
            );
            const balanceBefore = await contracts.unionToken.balanceOf(deployerAddress);
            await contracts.userManager.withdrawRewards();
            const balanceAfter = await contracts.unionToken.balanceOf(deployerAddress);
            expect(balanceAfter.sub(balanceBefore)).eq(rewards);
        });
        it("withdraw rewards when staking", async () => {
            await roll(10);
            const rewards = await contracts.comptroller.calculateRewardsByBlocks(
                deployerAddress,
                contracts.dai.address,
                1
            );
            const balanceBefore = await contracts.unionToken.balanceOf(deployerAddress);
            await contracts.userManager.stake(1);
            const balanceAfter = await contracts.unionToken.balanceOf(deployerAddress);
            expect(balanceAfter.sub(balanceBefore)).eq(rewards);
        });
        it("large staker has more rewards than small staker", async () => {
            const [, shrimp, whale] = signers;
            const shrimpAddress = await shrimp.getAddress();
            const whaleAddress = await whale.getAddress();

            await contracts.userManager.connect(shrimp).stake(parseUnits("1"));
            await contracts.userManager.connect(whale).stake(parseUnits("1000"));
            await roll(10);
            const shrimpRewards = await contracts.comptroller.calculateRewards(shrimpAddress, contracts.dai.address);
            const whaleRewards = await contracts.comptroller.calculateRewards(whaleAddress, contracts.dai.address);
            expect(shrimpRewards).lt(whaleRewards);
        });
        it("staker with frozen balance gets less rewards");
        it("staker with locked balance gets more rewards");
    });

    context("stake underwrites borrow", () => {
        before(beforeContext);
        it("cannot unstake when locked");
    });
});
