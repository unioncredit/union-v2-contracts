import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {fork, getDai, getDeployer, getSigners} from "../utils";
import {isForked} from "../utils/fork";

describe("Action gas cost", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let borrower: Signer;
    let staker: Signer;
    let stakerAddress: string;
    let borrowerAddress: string;
    let stakeGas: any,
        stakeGas2: any,
        vouchGas: any,
        vouchGas2: any,
        borrowGas: any,
        borrowGas2: any,
        repayGas: any,
        repayGas2: any;

    const borrowAmount = parseUnits("200");
    const stakeAmount = parseUnits("500");
    const mintAmount = parseUnits("2000");

    const beforeContext = async () => {
        if (isForked()) await fork();

        signers = await getSigners();
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        staker = signers[0];
        borrower = signers[1];

        stakerAddress = await staker.getAddress();
        borrowerAddress = await borrower.getAddress();
        await contracts.userManager.addMember(stakerAddress);
        await contracts.userManager.addMember(borrowerAddress);

        await getDai(contracts.dai, deployer, mintAmount);
        await contracts.dai.approve(contracts.uToken.address, ethers.constants.MaxUint256);
        await contracts.dai.connect(borrower).approve(contracts.uToken.address, ethers.constants.MaxUint256);
        await getDai(contracts.dai, staker, mintAmount);
        await contracts.dai.connect(staker).approve(contracts.userManager.address, ethers.constants.MaxUint256);
        await contracts.uToken.addReserves(mintAmount);
    };
    context("stake, vouch, borrow and repay gas cost", () => {
        beforeEach(beforeContext);
        it("Operation gas consumption", async () => {
            const stakeTx = await contracts.userManager.connect(staker).stake(stakeAmount);
            console.log("stake gas cost: " + stakeTx.gasLimit?.toString());
            const vouchTx = await contracts.userManager.connect(staker).updateTrust(borrowerAddress, stakeAmount);
            console.log("vouch gas cost: " + vouchTx.gasLimit?.toString());
            const borrowTx = await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
            console.log("borrow gas cost: " + borrowTx.gasLimit?.toString());
            const repayTx = await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
            console.log("repay gas cost: " + repayTx.gasLimit?.toString());

            console.log("second execution");

            const stakeTx2 = await contracts.userManager.connect(staker).stake(stakeAmount);
            stakeGas = stakeTx2.gasLimit;
            console.log("stake gas cost: " + stakeTx2.gasLimit?.toString());
            const vouchTx2 = await contracts.userManager.connect(staker).updateTrust(borrowerAddress, mintAmount);
            vouchGas = vouchTx2.gasLimit;
            console.log("vouch gas cost: " + vouchTx2.gasLimit?.toString());
            const borrowTx2 = await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
            borrowGas = borrowTx2.gasLimit;
            console.log("borrow gas cost: " + borrowTx2.gasLimit?.toString());
            const repayTx2 = await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
            repayGas = repayTx2.gasLimit;
            console.log("repay gas cost: " + repayTx2.gasLimit?.toString());
        });

        it("Operation gas consumption when having multiple registered users, ", async () => {
            const stakeTx = await contracts.userManager.connect(staker).stake(stakeAmount);
            console.log("stake gas cost: " + stakeTx.gasLimit?.toString());
            const vouchTx = await contracts.userManager.connect(staker).updateTrust(borrowerAddress, stakeAmount);
            console.log("vouch gas cost: " + vouchTx.gasLimit?.toString());
            const borrowTx = await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
            console.log("borrow gas cost: " + borrowTx.gasLimit?.toString());
            const repayTx = await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
            console.log("repay gas cost: " + repayTx.gasLimit?.toString());

            console.log(`add ${signers.length - 2} user and second execution`);
            for (let i = 2; i < signers.length; i++) {
                const userSigner = signers[i];
                const userAddress = await userSigner.getAddress();
                await contracts.userManager.addMember(userAddress);
                await getDai(contracts.dai, userSigner, parseUnits("200"));
                await contracts.dai
                    .connect(userSigner)
                    .approve(contracts.userManager.address, ethers.constants.MaxUint256);
                await contracts.userManager.connect(userSigner).stake(parseUnits("200"));
            }

            const stakeTx2 = await contracts.userManager.connect(staker).stake(stakeAmount);
            stakeGas2 = stakeTx2.gasLimit;
            console.log("stake gas cost: " + stakeTx2.gasLimit?.toString());
            const vouchTx2 = await contracts.userManager.connect(staker).updateTrust(borrowerAddress, mintAmount);
            vouchGas2 = vouchTx2.gasLimit;
            console.log("vouch gas cost: " + vouchTx2.gasLimit?.toString());
            const borrowTx2 = await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);
            borrowGas2 = borrowTx2.gasLimit;
            console.log("borrow gas cost: " + borrowTx2.gasLimit?.toString());
            const repayTx2 = await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, borrowAmount);
            repayGas2 = repayTx2.gasLimit;
            console.log("repay gas cost: " + repayTx2.gasLimit?.toString());
        });

        it("Compare gas consumption", async () => {
            console.log(`stake gas diff: ${stakeGas2.sub(stakeGas).toString()}`);
            console.log(`vouch gas diff: ${vouchGas2.sub(vouchGas).toString()}`);
            console.log(`borrow gas diff: ${borrowGas2.sub(borrowGas).toString()}`);
            console.log(`repay gas diff: ${repayGas2.sub(repayGas).toString()}`);
        });
    });
});
