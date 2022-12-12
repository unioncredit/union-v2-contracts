import {expect} from "chai";

import {Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

const PAD = 22;

describe("Reward issuance exploit fix", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const borrowAmount = parseUnits("1000");

    let stakingStartBlock: number;
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

        stakingStartBlock = await getBlockNumber();

        await contracts.dai.approve(contracts.uToken.address, AMOUNT);
        await contracts.uToken.mint(AMOUNT);

        await contracts.userManager.connect(staker).updateTrust(borrowerAddress, AMOUNT);

        const creditLine = await contracts.userManager.getCreditLimit(borrowerAddress);
        console.log("\nCredit line:".padEnd(PAD), commify(formatUnits(creditLine)));

        expect(creditLine).gt(0);
    });

    it("current rewards", async () => {
        const pastBlock = (await getBlockNumber()) - stakingStartBlock;
        console.log({pastBlock});
        const rewards = await contracts.comptroller.calculateRewards(stakerAddress, contracts.dai.address);
        console.log({rewards: rewards.toString()});
        expect(rewards).to.be.eq(STAKING_REWARDS_PER_BLOCK.mul(pastBlock));
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);
    });

    it("current rewards", async () => {
        const pastBlock = (await getBlockNumber()) - stakingStartBlock;
        console.log({pastBlock});
        const rewards = await contracts.comptroller.calculateRewards(stakerAddress, contracts.dai.address);
        console.log({rewards: commify(formatUnits(rewards))});
        const stakingRewards = STAKING_REWARDS_PER_BLOCK.mul(pastBlock - 1);
        expect(rewards).to.be.eq(BORROW_REWARDS_PER_BLOCK.add(stakingRewards));
    });
});
