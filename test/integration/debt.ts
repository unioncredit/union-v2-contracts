import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import error from "../utils/error";
import {isForked} from "../utils/fork";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";
import {fork, createHelpers, getDai, getDeployer, getSigners, Helpers, roll} from "../utils";

describe("Writing off member debt", () => {
    let deployer: Signer;
    let borrower: Signer;
    let user: Signer;
    let deployerAddress: string;
    let borrowerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;

    const beforeContext = async () => {
        if (isForked()) await fork();

        deployer = await getDeployer();
        const signers = await getSigners();

        borrower = signers[1];
        user = signers[2];

        deployerAddress = await deployer.getAddress();
        borrowerAddress = await borrower.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);
        await contracts.userManager.addMember(deployerAddress);
        await contracts.userManager.addMember(borrowerAddress);
        await contracts.userManager.setEffectiveCount(1);

        const amount = parseUnits("100000");
        const mintAmount = parseUnits("1000");
        const stakeAmount = parseUnits("1000");
        const borrowAmount = parseUnits("500");

        await getDai(contracts.dai, deployer, amount);
        await contracts.dai.approve(contracts.userManager.address, stakeAmount);
        await contracts.userManager.stake(stakeAmount);
        await contracts.userManager.updateTrust(borrowerAddress, stakeAmount);
        await contracts.dai.approve(contracts.uToken.address, mintAmount);
        await contracts.uToken.mint(mintAmount);
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
    };

    context("Staker writing off own locked stake", () => {
        before(beforeContext);
        it("borrower is not overdue", async () => {
            const amount = parseUnits("100");
            const lockedBefore = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
            await contracts.userManager.debtWriteOff(deployerAddress, borrowerAddress, amount);
            const lockedAfter = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
            expect(lockedAfter).eq(lockedBefore.sub(amount));
        });
        it("borrower is overdue", async () => {
            const amount = parseUnits("100");
            await helpers.withOverdueblocks(10, async () => {
                await roll(10);
                const lockedBefore = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
                await contracts.userManager.debtWriteOff(deployerAddress, borrowerAddress, amount);
                const lockedAfter = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
                expect(lockedAfter).eq(lockedBefore.sub(amount));
            });
        });
        it("write off entire debt", async () => {
            const locked = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
            await contracts.userManager.debtWriteOff(deployerAddress, borrowerAddress, locked);
            const lockedAfter = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
            expect(lockedAfter).eq(0);
        });
    });

    context("Public writing off debt", () => {
        before(beforeContext);
        it("cannot if not overdue", async () => {
            const amount = parseUnits("100");
            const resp = contracts.userManager.connect(user).debtWriteOff(deployerAddress, borrowerAddress, amount);
            await expect(resp).to.be.revertedWith(error.AuthFailed);
        });
        it("cannot if grace period has not passed", async () => {
            const amount = parseUnits("100");
            await helpers.withOverdueblocks(10, async () => {
                await roll(10);
                const resp = contracts.userManager.connect(user).debtWriteOff(deployerAddress, borrowerAddress, amount);
                await expect(resp).to.be.revertedWith(error.AuthFailed);
            });
        });
        it("public can write off debt", async () => {
            await contracts.userManager.setMaxOverdueBlocks(10);
            await helpers.withOverdueblocks(10, async () => {
                await roll(20);
                const locked = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
                await contracts.userManager.connect(user).debtWriteOff(deployerAddress, borrowerAddress, locked);
                const lockedAfter = await contracts.userManager.getLockedStake(deployerAddress, borrowerAddress);
                expect(lockedAfter).eq(0);
            });
        });
    });
});
