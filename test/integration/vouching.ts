import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import error from "../utils/error";
import {isForked} from "../utils/fork";
import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {fork, createHelpers, getDai, getDeployer, getSigners, Helpers} from "../utils";

describe("Vouching", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;

    const trustAmount = parseUnits("1000");

    before(async function () {});

    const beforeContext = async () => {
        if (isForked()) await fork();

        signers = await getSigners();
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);

        for (const signer of signers) {
            const address = await signer.getAddress();
            await contracts.userManager.addMember(address);
        }

        const amount = parseUnits("10000");

        for (const signer of signers) {
            await getDai(contracts.dai, signer, amount);
            await contracts.dai.connect(signer).approve(contracts.userManager.address, amount);
        }

        await getDai(contracts.dai, deployer, amount);
        await contracts.dai.approve(contracts.uToken.address, amount);
        await contracts.uToken.addReserves(amount);
    };

    context("Adjusting trust", () => {
        let staker: Signer;
        let borrower: Signer;

        before(async () => {
            await beforeContext();
            staker = signers[0];
            borrower = signers[1];
        });
        it("can only be called by a member", async () => {
            const resp = helpers.updateTrust(deployer, signers[0], parseUnits("10"));
            await expect(resp).to.be.revertedWith(error.AuthFailed);
        });
        it("cannot vouch for self", async () => {
            const resp = helpers.updateTrust(signers[0], signers[0], parseUnits("10"));
            await expect(resp).to.be.revertedWith(error.ErrorSelfVouching);
        });
        it("cannot increase vouch when updating trust with no stake", async () => {
            await helpers.updateTrust(staker, borrower, trustAmount);
            const [stakedAmount] = await helpers.getStakedAmounts(staker);
            const [vouchAmount] = await helpers.getVouchingAmounts(borrower, staker);

            expect(stakedAmount).eq(0);
            expect(vouchAmount).eq(0);
        });
        it("increase vouch when updating trust with stake", async () => {
            await helpers.stake(trustAmount, staker);
            const [stakedAmount] = await helpers.getStakedAmounts(staker);
            const [vouchAmount] = await helpers.getVouchingAmounts(borrower, staker);

            expect(stakedAmount).eq(trustAmount);
            expect(vouchAmount).eq(trustAmount);
        });
        it("can update trust on already trusted member", async () => {
            const newTrustAmount = trustAmount.div(2);
            const [vouchAmountBefore] = await helpers.getVouchingAmounts(borrower, staker);
            await helpers.updateTrust(staker, borrower, newTrustAmount);
            const [vouchAmountAfter] = await helpers.getVouchingAmounts(borrower, staker);

            expect(vouchAmountBefore).eq(trustAmount);
            expect(vouchAmountAfter).eq(newTrustAmount);
        });
        it("cannot reduce trust with locked amount", async () => {
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            await helpers.borrow(borrower, creditLimit.mul(900).div(1000));
            const resp = helpers.updateTrust(staker, borrower, 0);
            await expect(resp).to.be.revertedWith(error.TrustAmountLtLocked);
        });
    });

    context("Cancel vouch", () => {
        let staker: Signer;
        let borrower: Signer;

        before(async () => {
            await beforeContext();
            staker = signers[0];
            borrower = signers[1];
            await helpers.updateTrust(staker, borrower, trustAmount);
            await helpers.stake(trustAmount, staker);
        });
        it("only staker or borrower can cancel vouch", async () => {
            const resp = helpers.cancelVouch(staker, borrower, signers[3]);
            await expect(resp).to.be.revertedWith(error.AuthFailed);
        });
        it("cannot cancel a vouch with locked amount", async () => {
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            await helpers.borrow(borrower, creditLimit.mul(900).div(1000));
            const resp = helpers.cancelVouch(staker, borrower, staker);
            await expect(resp).to.be.revertedWith(error.LockedStakeNonZero);
        });
        it("cancelling vouch removes member from vouchers array and correctly re-indexes", async () => {
            await helpers.repayFull(borrower);
            await helpers.cancelVouch(staker, borrower, staker);
            const [vouchAmount] = await helpers.getVouchingAmounts(borrower, staker);
            expect(vouchAmount).eq(0);
        });
    });
});
