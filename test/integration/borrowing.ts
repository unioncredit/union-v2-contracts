import "./testSetup";

import {expect} from "chai";
import {BigNumber, BigNumberish, Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {createHelpers, fork, getDai, getDeployer, getSigners, Helpers, roll} from "../utils";
import {isForked} from "../utils/fork";
import error from "../utils/error";
import {signERC2612Permit} from "eth-permit";

describe("Borrowing and repaying", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let helpers: Helpers;
    let borrower: Signer;
    let staker: Signer;

    let borrowAmount: any, stakeAmount: any, mintAmount: any;
    const beforeContext = async () => {
        if (isForked()) await fork();

        signers = await getSigners();
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        helpers = createHelpers(contracts);
        staker = signers[0];
        borrower = signers[1];

        const stakerAddress = await staker.getAddress();
        const borrowerAddress = await borrower.getAddress();
        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);
        const decimals = await contracts.dai.decimals();
        borrowAmount = parseUnits("1000", decimals);
        stakeAmount = parseUnits("1500", decimals);
        mintAmount = parseUnits("10000", decimals);

        await getDai(contracts.dai, deployer, mintAmount);
        await contracts.dai.approve(contracts.uToken.address, ethers.constants.MaxUint256);
        await getDai(contracts.dai, staker, mintAmount);
        await contracts.dai.connect(staker).approve(contracts.userManager.address, ethers.constants.MaxUint256);
        await contracts.userManager.connect(staker).stake(stakeAmount);
    };

    context("Member borrows from credit line", () => {
        before(beforeContext);
        it("cannot borrow with no DAI in reserves", async () => {
            const resp = helpers.borrow(borrower, borrowAmount);
            await expect(resp).to.be.revertedWith(error.InsufficientFundsLeft);
        });
        it("add DAI to reservers", async () => {
            await contracts.uToken.addReserves(mintAmount);
        });
        it("cannot borrow with no available credit", async () => {
            const [creditLimit] = await helpers.getCreditLimits(borrower);
            expect(creditLimit).eq(0);
            const resp = helpers.borrow(borrower, borrowAmount);
            await expect(resp).to.be.revertedWith(error.LockedRemaining);
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
            await helpers.withOverdue(1, async () => {
                const minBorrow = await contracts.uToken.minBorrow();
                const resp = helpers.borrow(borrower, minBorrow);
                await expect(resp).to.be.revertedWith(error.MemberIsOverdue);
            });
        });
    });

    context("Borrowing interest/accounting", () => {
        let minBorrow: BigNumberish;
        before(async () => {
            await beforeContext();
            await contracts.uToken.addReserves(mintAmount);
            await helpers.updateTrust(staker, borrower, mintAmount);
            minBorrow = await contracts.uToken.minBorrow();
        });
        it("moves fee to reserves", async () => {
            const totalReservesBefore = await contracts.uToken.totalReserves();
            const fee = await contracts.uToken.calculatingFee(minBorrow);
            await helpers.borrow(borrower, minBorrow);
            const totalReservesAfter = await contracts.uToken.totalReserves();
            expect(totalReservesAfter.sub(totalReservesBefore)).eq(fee);
        });
        it("increases total borrows", async () => {
            const totalBorrowsBefore = await contracts.uToken.totalBorrows();
            await helpers.borrow(borrower, minBorrow);
            const totalBorrowsAfter = await contracts.uToken.totalBorrows();
            const borrowAmount = await helpers.borrowWithFee(minBorrow as BigNumber);
            expect(totalBorrowsAfter.sub(totalBorrowsBefore)).gte(borrowAmount);
        });
        it("Interest is accrued", async () => {
            const borrowIndexBefore = await contracts.uToken.borrowIndex();
            await roll(10);
            await contracts.uToken.accrueInterest();
            const borrowIndexAfter = await contracts.uToken.borrowIndex();
            expect(borrowIndexAfter).gt(borrowIndexBefore);
        });
    });

    context("Member repays debt", () => {
        beforeEach(async () => {
            await beforeContext();
            await contracts.uToken.addReserves(mintAmount);
            await helpers.updateTrust(staker, borrower, mintAmount);
            await helpers.borrow(borrower, borrowAmount);
        });
        it("cannot repay 0", async () => {
            const resp = contracts.uToken.repayBorrow(deployerAddress, 0);
            await expect(resp).to.be.revertedWith(error.AmountZero);
        });
        it("repay borrow with permit", async () => {
            const borrowerAddress = await borrower.getAddress();
            let amount = await contracts.uToken.borrowBalanceView(borrowerAddress);
            //ensure full repayment
            amount = amount.mul(BigNumber.from(2));
            //repay by deployer
            const daiBalance = await contracts.dai.balanceOf(deployerAddress);
            if (daiBalance.lt(amount) && "mint" in contracts.dai) {
                await contracts.dai.mint(deployerAddress, amount);
            }

            const result = await signERC2612Permit(
                ethers.provider,
                {
                    name: "DAI",
                    chainId: 31337,
                    version: "1",
                    verifyingContract: contracts.dai.address
                },
                deployerAddress,
                contracts.uToken.address,
                amount.toString()
            );

            await contracts.uToken.repayBorrowWithERC20Permit(
                borrowerAddress,
                amount,
                result.deadline,
                result.v,
                result.r,
                result.s
            );
            const borrowed = await contracts.uToken.getBorrowed(borrowerAddress);
            expect(borrowed).eq(0);
        });
        it("repaying less than interest doesn't update last repaid", async () => {
            const [lastRepayBefore] = await helpers.getBorrowed(borrower);
            await helpers.repay(borrower, 1);
            const [lastRepayAfter] = await helpers.getBorrowed(borrower);
            expect(lastRepayBefore).eq(lastRepayAfter);
        });
        it('unlocks stakers (in "first in first out" order)', async () => {
            const [, , lockedBefore] = await helpers.getVouchByIndex(borrower, 0);
            await helpers.repayFull(borrower);
            const [, , lockedAfter] = await helpers.getVouchByIndex(borrower, 0);
            expect(lockedBefore).gt(lockedAfter);
        });
    });
});
