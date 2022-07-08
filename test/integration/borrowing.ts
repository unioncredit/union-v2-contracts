import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";
import {createHelpers, Helpers} from "../utils";

describe("Borrowing and repaying", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;
    let borrower: Signer;
    let staker: Signer;

    const borrowAmount = parseUnits("1000");
    const stakeAmount = parseUnits("1500");
    const mintAmount = parseUnits("1000000");

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);
        staker = signers[0];
        borrower = signers[1];

        const stakerAddress = await staker.getAddress();
        const borrowerAddress = await borrower.getAddress();
        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);

        if ("mint" in contracts.dai) {
            await contracts.dai.mint(deployerAddress, mintAmount);
            await contracts.dai.approve(contracts.uToken.address, ethers.constants.MaxUint256);
            await contracts.dai.mint(stakerAddress, mintAmount);
            await contracts.dai.connect(staker).approve(contracts.userManager.address, ethers.constants.MaxUint256);
            await contracts.userManager.connect(staker).stake(stakeAmount);
        }
    };

    context("Member borrows from credit line", () => {
        before(beforeContext);
        it("cannot borrow with no DAI in reserves", async () => {
            const resp = helpers.borrow(borrower, borrowAmount);
            await expect(resp).to.be.revertedWith("InsufficientFundsLeft()");
        });
        it("add DAI to reservers", async () => {
            await contracts.uToken.addReserves(mintAmount);
        });
        it("cannot borrow with no available credit", async () => {
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            expect(creditLimit).eq(0);
            const resp = helpers.borrow(borrower, borrowAmount);
            await expect(resp).to.be.revertedWith("LockedRemaining()");
        });
        it("vouch for member", async () => {
            await helpers.updateTrust(staker, borrower, mintAmount);
        });
        it('locks stakers (in "first in" order)', async () => {
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            expect(creditLimit).eq(stakeAmount);
            await helpers.borrow(borrower, borrowAmount);
            const [, , locked] = await helpers.getVouch(staker, borrower);
            expect(locked).eq(await helpers.borrowWithFee(borrowAmount));
        });
        it("cannot borrow if overdue", async () => {
            await helpers.withOverdueblocks(1, async () => {
                const minBorrow = await contracts.uToken.minBorrow();
                const resp = helpers.borrow(borrower, minBorrow);
                await expect(resp).to.be.revertedWith("MemberIsOverdue()");
            });
        });
    });

    context("Borrowing interest/accounting", () => {
        before(beforeContext);
        it("moves fee to reserves");
        it("increases total borrows");
        it("changes uToken rate");
        it("Interest is accrued but not backed");
    });

    context("Member repays debt", () => {
        before(beforeContext);
        it("cannot repay 0");
        it("repaying less than interest doesn't update last repaid");
        it('unlocks stakers (in "first in first out" order)');
    });

    context("Repay interest/accounting", () => {
        before(beforeContext);
        it("reduces total borrows");
        it("changes uToken rate");
    });
});
