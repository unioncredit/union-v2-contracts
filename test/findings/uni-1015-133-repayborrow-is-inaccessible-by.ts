import {Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";
import {expect} from "chai";

const PAD = 22;

describe("Repay borrow when overdue", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const borrowAmount = parseUnits("5000");

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

    const logLoanAmounts = async () => {
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        const interest = await contracts.uToken.calculatingInterest(borrowerAddress);
        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);
        const totalBorrows = await contracts.uToken.totalBorrows();
        const totalRedeemable = await contracts.uToken.totalRedeemable();
        const totalReserves = await contracts.uToken.totalReserves();

        console.log("Principal:".padEnd(PAD), commify(formatUnits(principal)));
        console.log("Interest:".padEnd(PAD), commify(formatUnits(interest)));
        console.log("Total Owed:".padEnd(PAD), commify(formatUnits(owed)));
        console.log("Total Borrows:".padEnd(PAD), commify(formatUnits(totalBorrows)));
        console.log("Total Redeemable:".padEnd(PAD), commify(formatUnits(totalRedeemable)));
        console.log("Total reserves:".padEnd(PAD), commify(formatUnits(totalReserves)));
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

        await logLoanAmounts();
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);

        await logLoanAmounts();
    });

    it("wait until overdue time passes", async () => {
        await roll(20);

        await logLoanAmounts();
    });

    it("repay borrow when overdue", async () => {
        const isOverdue = await contracts.uToken.checkIsOverdue(borrowerAddress);

        console.log("Loan overdue:".padEnd(PAD), isOverdue.toString());
        console.log("");

        await contracts.dai.connect(borrower).approve(contracts.uToken.address, borrowAmount);
        await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).lt(borrowAmount);

        await logLoanAmounts();
    });
});
