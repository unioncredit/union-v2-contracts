import {expect} from "chai";
import error from "../utils/error";

import {BigNumber, Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

const PAD = 22;

describe("Write-off debt and cancel vouch", () => {
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

    const logLoanAmounts = async () => {
        const vouchInfo = await contracts.userManager.voucherIndexes(borrowerAddress, stakerAddress);
        if (vouchInfo.isSet) {
            const vouchAmount = await contracts.userManager.vouchers(borrowerAddress, vouchInfo.idx);
            console.log("\nVouch amount:".padEnd(PAD), commify(formatUnits(vouchAmount.trust)));
        } else {
            console.log("\nVouch amount:".padEnd(PAD), 0);
        }
        console.log("");
    };

    it("set up credit line", async () => {
        const AMOUNT = parseUnits("1005");

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
        console.log("\nCredit line:".padEnd(PAD), commify(formatUnits(creditLine)));

        expect(creditLine).gt(0);

        await logLoanAmounts();
    });

    it("borrow", async () => {
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        expect(principal).gt(borrowAmount);
    });

    it("wait until max overdue time passes", async () => {
        await roll(131);
    });

    it("3rd party can write off all debt, and vouch is cancelled", async () => {
        const principal = await contracts.uToken.getBorrowed(borrowerAddress);
        await expect(contracts.userManager.debtWriteOff(stakerAddress, borrowerAddress, principal))
            .to.emit(contracts.userManager, "LogCancelVouch")
            .withArgs(stakerAddress, borrowerAddress);

        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);
        expect(owed).eq(0);

        await logLoanAmounts();
    });
});
