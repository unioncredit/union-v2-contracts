import {expect} from "chai";
import {Signer} from "ethers";
import {formatUnits, parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";
import ora from "ora";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Max gas tests", () => {
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
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
        accounts = Array(accountCount)
            .fill(0)
            .map(() => {
                const wallet = ethers.Wallet.createRandom();
                return wallet.connect(ethers.provider);
            });

        for (const account of accounts) {
            const addr = await account.getAddress();
            contracts.userManager.addMember(addr);
            deployer.sendTransaction({to: addr, value: parseUnits("1")});
        }
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

            console.log(`[*] Min gas: ${min}, Max gas: ${max}, Delta: ${max - min}`);
        });
    });

    context("borrow max gas cost", () => {
        before(async () => await beforeContext(500));
        it("updateTrust", async () => {
            const trustAmount = parseUnits("1");
            const stakeAmount = parseUnits("1");

            const borrower = deployer;
            const borrowerAddress = deployerAddress;

            await contracts.userManager.addMember(borrowerAddress);
            if ("mint" in contracts.dai) {
                await contracts.dai.mint(borrowerAddress, parseUnits("10000000"));
                await contracts.dai.approve(contracts.uToken.address, parseUnits("10000000"));
                await contracts.uToken.addReserves(parseUnits("10000000"));
            }

            const stakers = accounts;

            const str = (n: number) => `Updating trust Staker: ${n}/${stakers.length}`;

            let spinner = ora(str(0)).start();

            for (let i = 0; i < stakers.length; i++) {
                const staker = stakers[i];
                if ("mint" in contracts.dai) {
                    const stakerAddress = await staker.getAddress();
                    await contracts.dai.connect(deployer).mint(stakerAddress, stakeAmount);
                    await contracts.dai
                        .connect(staker)
                        .approve(contracts.userManager.address, ethers.constants.MaxUint256);
                    await contracts.userManager.connect(staker).stake(stakeAmount);
                    await contracts.userManager.connect(staker).updateTrust(borrowerAddress, trustAmount);
                }
                spinner.text = str(i);
            }

            spinner.stop();

            const creditLimit = await contracts.userManager.getCreditLimit(borrowerAddress);
            const borrowAmount = creditLimit.mul(900).div(1000);
            spinner = ora(`Borrowing: ${formatUnits(creditLimit)}`).start();

            const tx = await contracts.uToken.connect(borrower).borrow(borrowAmount);
            const resp = await tx.wait();

            spinner.stop();

            console.log(`Gas used: ${resp.gasUsed}`);
        });
    });
});
