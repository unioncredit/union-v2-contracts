import * as fs from "fs";
import * as path from "path";

import ora from "ora";
import {Signer} from "ethers";
import {ethers} from "hardhat";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai} from "../../test/utils";

const ACCOUNT_COUNT = Number(process.env.ACCOUNT_COUNT || "10");

function saveReport(str: string, index: number) {
    const file = path.resolve(__dirname, "simulations-gas-snapshot.txt");
    const content = fs.readFileSync(file, "utf8");
    const arr = content.split("\n");
    arr[index] = str;
    fs.writeFileSync(file, arr.join("\n"));
}

describe("Max gas", () => {
    let accounts: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    before(async function () {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async (accountCount: number) => {
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        let spinner = ora(`Creating ${accountCount} wallets`).start();

        accounts = Array(accountCount)
            .fill(0)
            .map(() => {
                const wallet = ethers.Wallet.createRandom();
                return wallet.connect(ethers.provider);
            });

        spinner.stop();

        await contracts.uToken.setMaxBorrow(ethers.constants.MaxUint256);

        spinner = ora("Setting up accounts").start();

        for (const account of accounts) {
            const addr = await account.getAddress();
            contracts.userManager.addMember(addr);
            deployer.sendTransaction({to: addr, value: parseUnits("1")});
        }

        spinner.stop();
    };

    context("updateTrust has constant gas cost", () => {
        before(async () => await beforeContext(10));

        it("updateTrust", async () => {
            const trustAmount = parseUnits("100");

            const str = (n: number, x: number) =>
                `Updating trust Staker: ${n}/${accounts.length}, Borrower: ${x}/${accounts.length}`;

            const spinner = ora(str(0, 0)).start();

            let gasUsed = [];

            for (let i = 0; i < accounts.length; i++) {
                const staker = accounts[i];
                const stakerAddress = await staker.getAddress();
                for (let j = 0; j < accounts.length; j++) {
                    const borrower = accounts[j];
                    const borrowerAddress = await borrower.getAddress();
                    if (stakerAddress !== borrowerAddress) {
                        const tx = await contracts.userManager
                            .connect(staker)
                            .updateTrust(borrowerAddress, trustAmount);
                        const resp = await tx.wait();
                        gasUsed.push(resp.gasUsed);
                        spinner.text = str(i, j);
                    }
                }
            }

            const min = Math.min(...gasUsed.map(g => Number(g.toString())));
            const max = Math.max(...gasUsed.map(g => Number(g.toString())));

            spinner.stop();

            const reportStr = `[*] updateTrust:: Min gas: ${commify(min)}, Max gas: ${commify(max)}, Delta: ${commify(
                max - min
            )}`;
            saveReport(reportStr, 0);
            console.log(reportStr);
        });
    });

    context("borrow max gas cost", () => {
        before(async () => await beforeContext(ACCOUNT_COUNT));

        it("borrow", async () => {
            const trustAmount = parseUnits("100");
            const stakeAmount = parseUnits("100");

            const borrower = deployer;
            const borrowerAddress = deployerAddress;

            await contracts.userManager.addMember(borrowerAddress);
            await getDai(contracts.dai, borrower, parseUnits("10000000"));
            await contracts.dai.approve(contracts.uToken.address, parseUnits("10000000"));
            await contracts.uToken.addReserves(parseUnits("10000000"));

            const stakers = accounts;

            const str = (n: number) => `Updating trust Staker: ${n}/${stakers.length}`;

            let spinner = ora(str(0)).start();

            for (let i = 0; i < stakers.length; i++) {
                const staker = stakers[i];
                if ("mint" in contracts.dai) {
                    await getDai(contracts.dai, staker, stakeAmount);
                    await contracts.dai
                        .connect(staker)
                        .approve(contracts.userManager.address, ethers.constants.MaxUint256);
                    await contracts.userManager.connect(staker).stake(stakeAmount);
                    await contracts.userManager.connect(staker).updateTrust(borrowerAddress, trustAmount);
                }
                spinner.text = str(i);
            }

            spinner.stop();

            // ---------------------------------------------------
            // BORROW
            // ---------------------------------------------------
            const creditLimit = await contracts.userManager.getCreditLimit(borrowerAddress);
            const borrowAmount = creditLimit.mul(900).div(1000);
            spinner = ora(`Borrowing: ${formatUnits(creditLimit)}`).start();

            let tx = await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
            let resp = await tx.wait();

            spinner.stop();

            const reportStr = `[*] borrow:: count: ${stakers.length} borrow: ${commify(
                formatUnits(borrowAmount)
            )} creditLimit: ${commify(formatUnits(creditLimit))} Gas used: ${commify(resp.gasUsed.toString())}`;
            saveReport(reportStr, 1);
            console.log(reportStr);

            // ---------------------------------------------------
            // REPAY
            // ---------------------------------------------------

            await contracts.dai.connect(borrower).approve(contracts.uToken.address, borrowAmount);
            tx = await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
            resp = await tx.wait();

            const reportStr0 = `[*] repay:: count: ${stakers.length} borrow: ${commify(
                formatUnits(borrowAmount)
            )} creditLimit: ${commify(formatUnits(creditLimit))} Gas used: ${commify(resp.gasUsed.toString())}`;
            saveReport(reportStr0, 2);
            console.log(reportStr0);
        });
    });
    context("get stake info", () => {
        before(async () => await beforeContext(ACCOUNT_COUNT));
        it("getStakeInfo", async () => {
            const trustAmount = parseUnits("100");
            const staker = accounts[0];
            const stakerAddress = await staker.getAddress();

            await contracts.uToken.setMinBorrow(0);
            await contracts.uToken.setOverdueBlocks(0);

            const stakeAmount = parseUnits("10000");
            await getDai(contracts.dai, staker, stakeAmount.mul(2));
            await contracts.dai.connect(staker).approve(contracts.userManager.address, ethers.constants.MaxUint256);
            await contracts.userManager.connect(staker).stake(stakeAmount);
            await contracts.dai.connect(staker).approve(contracts.uToken.address, ethers.constants.MaxUint256);
            await contracts.uToken.connect(staker).addReserves(stakeAmount);

            const str = (n: number) => `Processing accounts: ${n}/${accounts.length}`;

            let spinner = ora(str(0)).start();

            for (let i = 0; i < accounts.length; i++) {
                const account = accounts[i];
                const addr = await account.getAddress();
                await contracts.userManager.addMember(addr);

                if (stakerAddress !== addr) {
                    await contracts.userManager.connect(staker).updateTrust(addr, trustAmount);
                    const creditLimit = await contracts.userManager.getCreditLimit(addr);
                    const borrowAmount = creditLimit.mul(950).div(1000);
                    await contracts.uToken.connect(account).borrow(addr, borrowAmount);
                }

                spinner.text = str(i);
            }

            spinner.stop();

            const gasUsed = await contracts.userManager.estimateGas.getStakeInfo(stakerAddress, 0);
            const reportStr = `[*] getStakeInfo:: count: ${ACCOUNT_COUNT} Gas used: ${commify(gasUsed.toString())}`;
            saveReport(reportStr, 3);
            console.log(reportStr);
        });
    });
});
