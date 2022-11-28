import {expect} from "chai";

import {Signer} from "ethers";
import {ethers} from "hardhat";
import {parseEther} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";

const IS_FIXED = true;

describe("Write-off debt and cancel vouch", () => {
    let staker: Signer;
    let stakerAddress: string;

    let borrowers: Signer[];

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    const trustAmount = parseEther("1");
    const trustAmounts = {};

    before(async function () {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        staker = signers[1];
        stakerAddress = await staker.getAddress();

        borrowers = signers.slice(2);
    });

    it("setup", async () => {
        await contracts.userManager.addMember(stakerAddress);

        for (const acc of borrowers) {
            const addr = await acc.getAddress();
            const nextIndex = await contracts.userManager.getVoucheeCount(stakerAddress);
            const ta = trustAmount.mul(nextIndex).add(trustAmount);
            // save ta
            trustAmounts[addr] = ta;

            await contracts.userManager.connect(staker).updateTrust(addr, ta);
            const vouchee = await contracts.userManager.vouchees(stakerAddress, nextIndex);
            expect(vouchee.borrower).eq(addr);

            const voucherIndex = await contracts.userManager.voucherIndexes(addr, stakerAddress);
            expect(voucherIndex.idx).eq(vouchee.voucherIndex);

            const vouch = await contracts.userManager.vouchers(addr, vouchee.voucherIndex);
            expect(vouch.staker).eq(stakerAddress);
            expect(vouch.trust).eq(ta);
            expect(vouch.locked).eq(0);
        }
    });
    it("cancelVouch corrupts order", async () => {
        const toCancel = await borrowers[0].getAddress();

        // ---------------------------------------------------------------
        // Before
        // ---------------------------------------------------------------
        {
            const voucheeIndex = await contracts.userManager.voucheeIndexes(toCancel, stakerAddress);
            const vouchee = await contracts.userManager.vouchees(stakerAddress, voucheeIndex.idx);
            expect(vouchee.borrower).eq(toCancel);

            const ta = trustAmount.mul(voucheeIndex.idx).add(trustAmount);

            const voucherIndex = await contracts.userManager.voucherIndexes(toCancel, stakerAddress);
            expect(voucherIndex.idx).eq(vouchee.voucherIndex);

            const vouch = await contracts.userManager.vouchers(toCancel, vouchee.voucherIndex);
            expect(vouch.staker).eq(stakerAddress);
            expect(vouch.trust).eq(ta);
            expect(vouch.locked).eq(0);
        }

        await contracts.userManager.connect(staker).cancelVouch(stakerAddress, toCancel);

        // ---------------------------------------------------------------
        // After
        // ---------------------------------------------------------------
        {
            const voucheeIndex = await contracts.userManager.voucheeIndexes(toCancel, stakerAddress);
            expect(voucheeIndex.isSet).eq(false);

            const voucherIndex = await contracts.userManager.voucherIndexes(toCancel, stakerAddress);
            expect(voucherIndex.isSet).eq(false);
        }
    });
    if (IS_FIXED) {
        it("vouchee.voucherIndex is updated correctly", async () => {
            const acc = borrowers.pop();
            const addr = await acc.getAddress();
            const ta = trustAmounts[addr];

            const voucheeIndex = await contracts.userManager.voucheeIndexes(addr, stakerAddress);
            const voucherIndex = await contracts.userManager.voucherIndexes(addr, stakerAddress);

            const vouchee = await contracts.userManager.vouchees(stakerAddress, voucheeIndex.idx);
            expect(vouchee.voucherIndex).eq(voucherIndex.idx);

            const vouch = await contracts.userManager.vouchers(addr, voucherIndex.idx);
            expect(vouch.trust).eq(ta);
        });
    } else {
        it("vouchee.voucherIndex is not updated correctly", async () => {
            const acc = borrowers.pop();
            const addr = await acc.getAddress();
            const ta = trustAmounts[addr];

            const voucheeIndex = await contracts.userManager.voucheeIndexes(addr, stakerAddress);
            const voucherIndex = await contracts.userManager.voucherIndexes(addr, stakerAddress);

            const voucheeCount = await contracts.userManager.getVoucheeCount(stakerAddress);
            expect(voucheeIndex.idx).gt(voucheeCount.sub(1));

            // The vouchee.voucherIndex has not been updated correctly and is still pointing to the
            // old voucherIndex which was the lastIndex. This index doesn't exist anymore so when
            // we try and retrieve it it will revert.
            await expect(contracts.userManager.vouchees(stakerAddress, voucheeIndex.idx)).to.be.reverted;
        });
    }
});
