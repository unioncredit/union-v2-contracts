import {BigNumber, Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll, warp} from "../../test/utils";
import {expect} from "chai";

const PAD = 22;

describe("Bad debt", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const borrowAmount = parseUnits("5000");

    let interest: BigNumber;
    let principal: BigNumber;

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

    const logExchangeRate = async () => {
        const exchangeRate = await contracts.uToken.exchangeRateStored();

        console.log("Exchange rate:".padEnd(PAD), commify(formatUnits(exchangeRate)));
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
        await logExchangeRate();
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);
    });

    it("accrue interest", async () => {
        console.log("Roll 10,000 blocks into the future");
        await roll(10000);

        await contracts.uToken.accrueInterest();

        interest = await contracts.uToken.calculatingInterest(borrowerAddress);
        principal = await contracts.uToken.getBorrowed(borrowerAddress);
        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);

        expect(owed).gte(principal.add(interest));

        await logLoanAmounts();
        await logExchangeRate();
    });

    it("write off debt", async () => {
        const stakeBalBefore = await contracts.userManager.getStakerBalance(stakerAddress);
        await contracts.userManager.connect(staker).debtWriteOff(stakerAddress, borrowerAddress, principal);
        const stakeBalAfter = await contracts.userManager.getStakerBalance(stakerAddress);
        expect(stakeBalBefore.sub(stakeBalAfter)).eq(principal);

        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);
        expect(owed).eq(0);

        await logLoanAmounts();
        await logExchangeRate();
    });
});
