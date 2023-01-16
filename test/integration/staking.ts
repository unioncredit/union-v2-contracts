import "./testSetup";

import {expect} from "chai";
import {ethers} from "hardhat";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import error from "../utils/error";
import {isForked} from "../utils/fork";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";
import {createHelpers, roll, Helpers, getDeployer, getSigners, getDai, getUnion, fork} from "../utils";
import {signERC2612Permit} from "eth-permit";

describe("Staking and unstaking", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;
    // Non member accounts
    let accounts: Signer[];
    // Member accounts
    let members: Signer[];

    const beforeContext = async () => {
        if (isForked()) await fork();

        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        const signers = await getSigners();
        accounts = signers.slice(-(signers.length / 2));
        members = signers.slice(0, signers.length / 2);

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);

        const stakeAmount = await contracts.userManager.maxStakeAmount();

        for (const signer of [deployer, ...accounts, ...members]) {
            const amount = stakeAmount;
            await getDai(contracts.dai, signer, amount);
            await contracts.dai.connect(signer).approve(contracts.userManager.address, ethers.constants.MaxUint256);
        }

        for (const member of members) {
            const address = await member.getAddress();
            await contracts.userManager.connect(member).stake(stakeAmount);
            await contracts.userManager.addMember(address);
        }
    };

    context("staking and unstaking as a non member", () => {
        before(beforeContext);
        it("cannot stake more than limit", async () => {
            const maxStake = await contracts.userManager.maxStakeAmount();
            await expect(contracts.userManager.stake(maxStake.add(1))).to.be.revertedWith(error.StakeLimitReached);
        });
        it("stake with DAI permit", async () => {
            const stakeAmount = parseUnits("1");
            const stakeBalBefore = await contracts.userManager.getStakerBalance(deployerAddress);

            const result = await signERC2612Permit(
                ethers.provider,
                {
                    name: "DAI",
                    chainId: 31337,
                    version: "1",
                    verifyingContract: contracts.dai.address
                },
                deployerAddress,
                contracts.userManager.address,
                stakeAmount.toString()
            );

            await contracts.userManager.stakeWithERC20Permit(
                stakeAmount,
                result.deadline,
                result.v,
                result.r,
                result.s
            );
            const stakeBalAfter = await contracts.userManager.getStakerBalance(deployerAddress);

            expect(stakeBalAfter.sub(stakeBalBefore)).eq(stakeAmount);
        });
        it("transfers underlying token to assetManager", async () => {
            const stakeAmount = parseUnits("100");
            const assetManagerBalanceBefore = await contracts.assetManager.getPoolBalance(contracts.dai.address);
            const totalStakedBefore = await contracts.userManager.totalStaked();
            await contracts.dai.approve(contracts.userManager.address, stakeAmount);
            await contracts.userManager.stake(stakeAmount);
            const totalStakedAfter = await contracts.userManager.totalStaked();
            const assetManagerBalanceAfter = await contracts.assetManager.getPoolBalance(contracts.dai.address);

            expect(totalStakedAfter.sub(totalStakedBefore)).eq(stakeAmount);
            expect(assetManagerBalanceAfter.sub(assetManagerBalanceBefore)).eq(stakeAmount);
        });
        it("cannot unstake more than staked", async () => {
            const stakeAmount = await contracts.userManager.getStakerBalance(deployerAddress);
            const resp = contracts.userManager.unstake(stakeAmount.add(1));
            await expect(resp).to.be.revertedWith(error.InsufficientBalance);
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

            const amount = parseUnits("10000");
            await getUnion(contracts.unionToken, contracts.comptroller.address, amount);
            await getDai(contracts.dai, deployer, amount);
            await contracts.dai.approve(contracts.uToken.address, amount);
            await contracts.uToken.addReserves(amount);
        });
        it("stake", async () => {
            const stakeAmount = parseUnits("100");
            await contracts.userManager.stake(stakeAmount);
        });
        it("withdraw rewards from comptroller", async () => {
            await roll(1);
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
            await roll(1);
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
            const [, shrimp, whale] = accounts;
            await helpers.stake(parseUnits("1"), shrimp);
            await helpers.stake(parseUnits("1000"), whale);
            await roll(1);
            const [shrimpRewards, whaleRewards] = await helpers.calculateRewards(shrimp, whale);
            expect(shrimpRewards).lt(whaleRewards);
        });
        it("staker with locked balance gets more rewards", async () => {
            const trustAmount = parseUnits("2000");
            const borrowAmount = parseUnits("1950");
            const [account, staker, borrower] = members;

            const [accountStaked, borrowerStaked, stakerStaked] = await helpers.getStakedAmounts(
                account,
                staker,
                borrower
            );

            expect(accountStaked).eq(borrowerStaked);
            expect(borrowerStaked).eq(stakerStaked);

            await helpers.updateTrust(staker, borrower, trustAmount);
            await helpers.borrow(borrower, borrowAmount);

            await roll(10);
            const [accountMultiplier, stakerMultiplier] = await helpers.getRewardsMultipliers(account, staker);
            expect(accountMultiplier).lt(stakerMultiplier);
        });
        it("staker with frozen balance gets less rewards", async () => {
            const [, staker, borrower] = members;
            const borrowerAddress = await borrower.getAddress();
            const [multiplierBefore] = await helpers.getRewardsMultipliers(staker);

            await helpers.withOverdueblocks(1, async () => {
                const isOverdue = await contracts.uToken.checkIsOverdue(borrowerAddress);
                expect(isOverdue).eq(true);
                await roll(10);
                const [multiplierAfter] = await helpers.getRewardsMultipliers(staker);
                expect(multiplierBefore).gt(multiplierAfter);
            });
        });
    });

    context("stake underwrites borrow", () => {
        before(async () => {
            await beforeContext();

            const amount = parseUnits("10000");

            await getUnion(contracts.unionToken, contracts.comptroller.address, amount);
            await getDai(contracts.dai, deployer, amount);
            await contracts.dai.approve(contracts.uToken.address, amount);
            await contracts.uToken.addReserves(amount);
        });
        it("cannot unstake when locked", async () => {
            const trustAmount = parseUnits("2000");
            const borrowAmount = parseUnits("1950");
            const [staker, borrower] = members;
            const [stakedAmount] = await helpers.getStakedAmounts(staker);

            await helpers.updateTrust(staker, borrower, trustAmount);
            await helpers.borrow(borrower, borrowAmount);

            const resp = contracts.userManager.connect(staker).unstake(stakedAmount);
            await expect(resp).to.be.revertedWith(error.InsufficientBalance);
        });
    });
});
