import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import {getConfig} from "../../deploy/config";
import {createHelpers, getSigners, getDai, getDeployer, warp, Helpers} from "../utils";

import deploy, {Contracts} from "../../deploy";

import {PureTokenAdapter} from "../../typechain-types";

describe("Pure Token Adapter", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;
    let borrower: Signer;
    let staker: Signer;
    let adapter: PureTokenAdapter;

    const borrowAmount = parseUnits("1000");
    const stakeAmount = parseUnits("1500");
    const mintAmount = parseUnits("10000");

    before(async function () {
        signers = await getSigners();
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);
        staker = signers[0];
        borrower = signers[1];

        const stakerAddress = await staker.getAddress();
        const borrowerAddress = await borrower.getAddress();
        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);

        await getDai(contracts.dai, deployer, mintAmount);
        await contracts.dai.approve(contracts.uToken.address, ethers.constants.MaxUint256);
        await getDai(contracts.dai, staker, mintAmount);
        await contracts.dai.connect(staker).approve(contracts.userManager.address, ethers.constants.MaxUint256);

        adapter = contracts.adapters.pureTokenAdapter;
        await adapter.setCeiling(contracts.dai.address, ethers.constants.MaxUint256);
        await contracts.userManager.connect(staker).stake(stakeAmount);
        await helpers.updateTrust(staker, borrower, stakeAmount);
    };

    context("Deposit and Withdraw", () => {
        before(beforeContext);

        it("add DAI to reservers", async () => {
            let adapterBal = await adapter.getSupplyView(contracts.dai.address);
            expect(adapterBal).eq(stakeAmount);
            await contracts.uToken.addReserves(mintAmount);
            adapterBal = await adapter.getSupplyView(contracts.dai.address);
            expect(adapterBal).eq(mintAmount.add(stakeAmount));
        });

        it("borrow and locks stakers", async () => {
            const borrowerAddress = await borrower.getAddress();
            let bal = await contracts.dai.balanceOf(borrowerAddress);
            expect(bal).eq(0);
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            expect(creditLimit).eq(stakeAmount);
            await helpers.borrow(borrower, borrowAmount);
            const [, , locked] = await helpers.getVouch(staker, borrower);
            expect(locked).eq(await helpers.borrowWithFee(borrowAmount));
            const adapterBal = await await adapter.getSupplyView(contracts.dai.address);
            expect(adapterBal).eq(mintAmount.add(stakeAmount).sub(borrowAmount));
            bal = await contracts.dai.balanceOf(borrowerAddress);
            expect(bal).eq(borrowAmount);
        });

        it("cannot borrow if overdue", async () => {
            await helpers.withOverdue(1, async () => {
                const minBorrow = await contracts.uToken.minBorrow();
                const resp = helpers.borrow(borrower, minBorrow);
                await expect(resp).to.be.revertedWithCustomError(contracts.uToken, "MemberIsOverdue");
            });
        });

        it("repaying less than interest doesn't update last repaid", async () => {
            const [lastRepayBefore] = await helpers.getBorrowed(borrower);
            await helpers.repay(borrower, 1);
            const [lastRepayAfter] = await helpers.getBorrowed(borrower);
            expect(lastRepayBefore).eq(lastRepayAfter);
        });

        it("repay and unlocks stakers", async () => {
            const repayAmount = parseUnits("500");
            const [, , lockedBefore] = await helpers.getVouchByIndex(borrower, 0);
            await helpers.repay(borrower, repayAmount);
            const [, , lockedAfter] = await helpers.getVouchByIndex(borrower, 0);
            expect(lockedBefore).gt(lockedAfter);
            const adapterBal = await adapter.getSupplyView(contracts.dai.address);
            expect(adapterBal).gt(mintAmount.add(stakeAmount).sub(borrowAmount).add(repayAmount));
        });
    });
});
