import {expect} from "chai";
import {ethers} from "hardhat";
import {Signer} from "ethers";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

const PAD = 22;

describe("Debt write off", () => {
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

    const logInfo = async () => {
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        const interest = await contracts.uToken.calculatingInterest(borrowerAddress);
        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);
        const totalBorrows = await contracts.uToken.totalBorrows();
        const totalRedeemable = await contracts.uToken.totalRedeemable();
        const totalReserves = await contracts.uToken.totalReserves();

        console.log("");
        console.log("Principal:".padEnd(PAD), commify(formatUnits(principal)));
        console.log("Interest:".padEnd(PAD), commify(formatUnits(interest)));
        console.log("Total Owed:".padEnd(PAD), commify(formatUnits(owed)));
        console.log("Total Borrows:".padEnd(PAD), commify(formatUnits(totalBorrows)));
        console.log("Total Redeemable:".padEnd(PAD), commify(formatUnits(totalRedeemable)));
        console.log("Total reserves:".padEnd(PAD), commify(formatUnits(totalReserves)));
        console.log("");

        const balance = await contracts.userManager.getStakerBalance(stakerAddress);

        console.log("Staker balance:".padEnd(PAD), commify(formatUnits(balance)));
        console.log("");

        const lastRepay = await contracts.uToken.getLastRepay(borrowerAddress);
        console.log("Borrower's last repay:".padEnd(PAD), lastRepay.toString());
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
        console.log("Credit line:".padEnd(PAD), commify(formatUnits(creditLine)));

        expect(creditLine).gt(0);

        await logInfo();
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);

        await logInfo();
    });

    it("staker writes off debt", async () => {
        const stakeBalBefore = await contracts.userManager.getStakerBalance(stakerAddress);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        await contracts.userManager.connect(staker).debtWriteOff(stakerAddress, borrowerAddress, principal);
        const stakeBalAfter = await contracts.userManager.getStakerBalance(stakerAddress);
        expect(stakeBalBefore.sub(stakeBalAfter)).eq(principal);

        await logInfo();
    });

    it("wait until max overdue time passes", async () => {
        console.log("\nRoll 200 blocks into the future and borrow again\n");
        await roll(200); // wait until the max overdue blocks passes
    });

    it("borrow again", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);

        await logInfo();
    });

    it("Cannot write off debt by others", async () => {
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        const resp = contracts.userManager.debtWriteOff(stakerAddress, borrowerAddress, principal);
        await expect(resp).to.be.revertedWithCustomError(contracts.userManager, "AuthFailed");

        await logInfo();
    });

    it("Can write off debt by the staker", async () => {
        const stakeBalBefore = await contracts.userManager.getStakerBalance(stakerAddress);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        await contracts.userManager.connect(staker).debtWriteOff(stakerAddress, borrowerAddress, principal);
        const stakeBalAfter = await contracts.userManager.getStakerBalance(stakerAddress);
        expect(stakeBalBefore.sub(stakeBalAfter)).eq(principal);

        await logInfo();
    });
});
