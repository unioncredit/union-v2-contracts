import {expect} from "chai";

import {Signer} from "ethers";
import {ethers} from "hardhat";
import {formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

const PAD = 22;

describe("Withdraw rewards before repaying borrows", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const borrowAmount = parseUnits("1000");

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

    const logStakeInfo = async () => {
        const stakeInfo = await contracts.userManager.getStakeInfo(stakerAddress);
        console.log("Effective Staked: ".padEnd(PAD), formatUnits(stakeInfo.effectiveStaked));
        console.log("Effective Locked: ".padEnd(PAD), formatUnits(stakeInfo.effectiveLocked));
        console.log("Staker frozen: ".padEnd(PAD), formatUnits(stakeInfo.stakerFrozen));
        console.log("");
    };

    it("set up credit line", async () => {
        const AMOUNT = parseUnits("10000");

        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);

        await getDai(contracts.dai, deployer, AMOUNT);
        await getDai(contracts.dai, staker, AMOUNT);

        await contracts.dai.connect(staker).approve(contracts.userManager.address, AMOUNT);
        await contracts.userManager.connect(staker).stake(AMOUNT);

        await contracts.dai.approve(contracts.uToken.address, AMOUNT);
        await contracts.uToken.mint(AMOUNT);

        await contracts.userManager.connect(staker).updateTrust(borrowerAddress, AMOUNT);

        const creditLine = await contracts.userManager.getCreditLimit(borrowerAddress);

        expect(creditLine).gt(0);
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const borrowed = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(borrowed).gt(borrowAmount);
    });

    it("withdraw rewards before overdue", async () => {
        await roll(5);

        const isOVerdue = await contracts.uToken.checkIsOverdue(borrowerAddress);
        expect(isOVerdue).to.be.false;

        await contracts.userManager.connect(staker).withdrawRewards();

        await logStakeInfo();
    });

    it("wait until max overdue time passes", async () => {
        await roll(5);

        const isOVerdue = await contracts.uToken.checkIsOverdue(borrowerAddress);
        expect(isOVerdue).to.be.true;

        await logStakeInfo();
    });

    it("frozenCoinAge should be accumulated after overdue", async () => {
        await contracts.userManager.connect(staker).withdrawRewards();
        await logStakeInfo();
        // stored frozen amount should be total borrowed
        const stakeFrozen = await contracts.userManager.memberFrozen(stakerAddress);
        const borrowed = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(stakeFrozen).to.be.eq(borrowed);
    });
});
