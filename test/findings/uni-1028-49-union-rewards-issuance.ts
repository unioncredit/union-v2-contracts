import {expect} from "chai";

import {BigNumber, Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

const PAD = 22;

describe("2x reward multiplier only when ppl borrowing", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const borrowAmount = parseUnits("1000");

    let stakingBlock: number, borrowBlock: number;
    const STAKING_REWARDS_PER_BLOCK = parseUnits("0.6");
    const BORROW_REWARDS_PER_BLOCK = parseUnits("0.6603");

    before(async function () {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        staker = signers[1];
        stakerAddress = await staker.getAddress();

        borrower = signers[2];
        borrowerAddress = await borrower.getAddress();
    });

    const getBlockNumber = async () => {
        const latestBlock = await ethers.provider.getBlock("latest");
        return latestBlock ? latestBlock.number : 0;
    };

    it("set up credit line", async () => {
        const AMOUNT = parseUnits("10000");

        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);

        await getDai(contracts.dai, deployer, AMOUNT);
        await getDai(contracts.dai, staker, AMOUNT);

        await contracts.dai.connect(staker).approve(contracts.userManager.address, AMOUNT);
        await contracts.userManager.connect(staker).stake(AMOUNT);

        stakingBlock = await getBlockNumber();
        console.log("\nStake block #:".padEnd(PAD), stakingBlock);

        await contracts.dai.approve(contracts.uToken.address, AMOUNT);
        await contracts.uToken.mint(AMOUNT);

        await contracts.userManager.connect(staker).updateTrust(borrowerAddress, AMOUNT);

        const creditLine = await contracts.userManager.getCreditLimit(borrowerAddress);

        expect(creditLine).gt(0);
    });

    it("rewards bofore borrow", async () => {
        const blocksSinceStaking = (await getBlockNumber()) - stakingBlock;
        console.log("\n#blocks since staking:".padEnd(PAD), blocksSinceStaking);
        const rewards = await contracts.comptroller.calculateRewards(stakerAddress, contracts.dai.address);
        console.log("\nUnclaimed rewards:".padEnd(PAD), commify(formatUnits(rewards)));
        expect(rewards).to.be.eq(STAKING_REWARDS_PER_BLOCK.mul(blocksSinceStaking));
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);
    });

    it("rewards after borrow", async () => {
        borrowBlock = await getBlockNumber();
        console.log("\nBorrow block #:".padEnd(PAD), borrowBlock);

        // increase 1 block to accrue rewards
        const blocksAfterBorrow = 1;
        await roll(blocksAfterBorrow);

        const rewards = await contracts.comptroller.calculateRewards(stakerAddress, contracts.dai.address);
        console.log("\nUnclaimed rewards:".padEnd(PAD), commify(formatUnits(rewards)));

        const rewardsBeforeBorrow = STAKING_REWARDS_PER_BLOCK.mul(borrowBlock - stakingBlock);
        const rewardsAfterBorrow = BORROW_REWARDS_PER_BLOCK.mul(blocksAfterBorrow);
        expect(rewards).to.be.eq(rewardsAfterBorrow.add(rewardsBeforeBorrow));
    });

    it("repay all", async () => {
        // get some extra dai to the borrower for the repayment
        const repayAmount = parseUnits("2000");
        await getDai(contracts.dai, borrower, repayAmount);
        await contracts.dai.connect(borrower).approve(contracts.uToken.address, repayAmount);

        await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, repayAmount);

        const borrowedAmount = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(borrowedAmount).eq(parseUnits("0"));
    });

    it("rewards after repay all", async () => {
        const repayBlock = await getBlockNumber();
        console.log("\nRepay block #:".padEnd(PAD), repayBlock);

        // increase x block to accrue rewards
        const blocksAfterRepay = 2;
        await roll(blocksAfterRepay);

        const rewards = await contracts.comptroller.calculateRewards(stakerAddress, contracts.dai.address);
        console.log("\nUnclaimed rewards:".padEnd(PAD), commify(formatUnits(rewards)));

        const rewardsBeforeBorrow = STAKING_REWARDS_PER_BLOCK.mul(borrowBlock - stakingBlock);
        const rewardsAfterBorrow = BORROW_REWARDS_PER_BLOCK.mul(repayBlock - borrowBlock);
        const rewardsAfterRepay = STAKING_REWARDS_PER_BLOCK.mul(blocksAfterRepay);
        expect(rewards).to.be.eq(rewardsBeforeBorrow.add(rewardsAfterBorrow).add(rewardsAfterRepay));
    });
});
