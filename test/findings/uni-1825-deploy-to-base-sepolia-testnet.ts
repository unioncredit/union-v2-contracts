const {ethers, getChainId} = require("hardhat");
const {parseEther, parseUnits} = require("ethers").utils;
const {expect} = require("chai");
require("chai").should();
const axios = require("axios");
require("dotenv").config();

const UnionTokenABI = require("../abis/UnionToken.json");
const UserManagerABI = require("../abis/UserManager.json");
const UTokenABI = require("../abis/UToken.json");
const UsdcABI = require("../abis/USDC.json");
const AssetManagerABI = require("../abis/AssetManager.json");

const usdcAddress = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
const userManagerAddress = "0x4C52c9E49aa6a5029c0F94753c533DFEBcf8AabA";
const uTokenAddress = "0x01Cc03de0742dF77b934C3aFA848AE2BB73576Ed";
const opUnionAddress = "0xc124047253c87EF90aF9f4EFC12C281b479c4769";
const assetManagerAddress = "0x311B84A6ca1196efd1CEc7E4fa09D8C2C171492A";

let forkId, forkRPC, opts;
let stakerAddress = "0x800C13848B469d207e1D02129Dc329818F652812",
    stakerSigner,
    borrowerAddress = "0xFEc6b01B950f07da5d0BA13Bf525Aec1534f7B59",
    borrowerSigner,
    unionHolderAddress = "0xcbd1c32a1b3961cc43868b8bae431ab0da65beeb",
    unionHolderSigner,
    usdcHolderAddress = "0xfaec9cdc3ef75713b48f46057b98ba04885e3391",
    usdcHolderSigner;
let opUnion, userManager, usdc, uToken, assetManager;
describe("Simulating test deploy contract on tenderly ...", () => {
    const startBlock = 11468000;
    const {TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY} = process.env;

    before(async () => {
        axios.create({
            baseURL: "https://api.tenderly.co/api/v1",
            headers: {
                "X-Access-Key": TENDERLY_ACCESS_KEY || "",
                "Content-Type": "application/json"
            }
        });

        opts = {
            headers: {
                "X-Access-Key": TENDERLY_ACCESS_KEY
            }
        };

        const TENDERLY_FORK_API = `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`;
        const body = {
            network_id: "84532",
            block_number: startBlock
        };
        const res = await axios.post(TENDERLY_FORK_API, body, opts);
        forkId = res.data.simulation_fork.id;
        console.log(`forkId: ${forkId}`);
        forkRPC = `https://rpc.tenderly.co/fork/${forkId}`;
        const provider = new ethers.providers.JsonRpcProvider(forkRPC);
        ethers.provider = provider;
        await provider.send("tenderly_setBalance", [
            [stakerAddress, borrowerAddress, unionHolderAddress, usdcHolderAddress],
            ethers.utils.hexValue(ethers.utils.parseUnits("10", "ether").toHexString())
        ]);
        stakerSigner = await ethers.provider.getSigner(stakerAddress);
        borrowerSigner = await ethers.provider.getSigner(borrowerAddress);
        usdcHolderSigner = await ethers.provider.getSigner(usdcHolderAddress);
        unionHolderSigner = await ethers.provider.getSigner(unionHolderAddress);

        assetManager = await ethers.getContractAt(AssetManagerABI, assetManagerAddress, stakerSigner);
        opUnion = await ethers.getContractAt(UnionTokenABI, opUnionAddress, stakerSigner);
        userManager = await ethers.getContractAt(UserManagerABI, userManagerAddress, stakerSigner);
        usdc = await ethers.getContractAt(UsdcABI, usdcAddress, stakerSigner);
        uToken = await ethers.getContractAt(UTokenABI, uTokenAddress, stakerSigner);

        await opUnion.connect(unionHolderSigner).transfer(stakerAddress, parseUnits("100", 6));
        await usdc.connect(usdcHolderSigner).transfer(stakerAddress, parseUnits("10000", 6));
        await usdc.connect(usdcHolderSigner).transfer(borrowerAddress, parseUnits("10000", 6));
    });

    it("register member", async () => {
        const newMemberFee = await userManager.newMemberFee();
        await opUnion.connect(stakerSigner).approve(userManagerAddress, newMemberFee.mul(2));
        await userManager.connect(stakerSigner).registerMember(stakerAddress);
        await userManager.connect(stakerSigner).registerMember(borrowerAddress);
    });

    it("stake and unstake", async () => {
        const stakeAmount = parseUnits("2000", 6);
        await usdc.connect(stakerSigner).approve(userManagerAddress, stakeAmount);
        const stakeTx = await userManager.connect(stakerSigner).stake(stakeAmount);
        await stakeTx.wait();
        const unstakeAmount = parseUnits("1000", 6);
        const unstakeTx = await userManager.connect(stakerSigner).unstake(unstakeAmount);
        await unstakeTx.wait();
        const stakeBalance = await userManager.getStakerBalance(stakerAddress);
        expect(stakeBalance).to.be.eq(parseUnits("1000", 6)); //2000-1000
    });

    it("update and cancel trust", async () => {
        const trustAmount = parseUnits("1000", 6);
        const trustTx = await userManager.connect(stakerSigner).updateTrust(borrowerAddress, trustAmount);
        await trustTx.wait();
        let creditLimit = await userManager.getCreditLimit(borrowerAddress);
        expect(creditLimit).to.be.eq(trustAmount);
        const trustTx2 = await userManager.connect(stakerSigner).cancelVouch(stakerAddress, borrowerAddress);
        await trustTx2.wait();
        creditLimit = await userManager.getCreditLimit(borrowerAddress);
        expect(creditLimit).to.be.eq(0);
        const trustTx3 = await userManager.connect(stakerSigner).updateTrust(borrowerAddress, trustAmount);
        await trustTx3.wait();
    });

    it("withdraw rewards", async () => {
        const befUniBal = await opUnion.balanceOf(stakerAddress);
        const withdrawRewardsTx = await userManager.connect(stakerSigner).withdrawRewards();
        await withdrawRewardsTx.wait();
        const aftUniBal = await opUnion.balanceOf(stakerAddress);
        expect(aftUniBal.sub(befUniBal)).gt(0);
    });

    it("mint and redeem", async () => {
        const uTokenBefBal = await uToken.balanceOf(stakerAddress);
        const mintAmount = parseUnits("1000", 6);
        await usdc.connect(stakerSigner).approve(uTokenAddress, mintAmount);
        const mintTx = await uToken.connect(stakerSigner).mint(mintAmount);
        await mintTx.wait();
        const uTokenMidBal = await uToken.balanceOf(stakerAddress);
        expect(uTokenMidBal.sub(uTokenBefBal)).gt(0);
        const redeemAmount = parseUnits("1000", 6);
        const redeemTx = await uToken.connect(stakerSigner).redeem(0, redeemAmount);
        await redeemTx.wait();
        const uTokenAfterBal = await uToken.balanceOf(stakerAddress);
        expect(uTokenAfterBal.sub(uTokenBefBal)).to.be.eq(0);
    });

    it("add reserves and remove reserves", async () => {
        const befTotalReserves = await uToken.totalReserves();
        const addReservesAmount = parseUnits("1000", 6);
        await usdc.connect(stakerSigner).approve(uTokenAddress, addReservesAmount.mul(2));
        const addReservesTx = await uToken.connect(stakerSigner).addReserves(addReservesAmount);
        await addReservesTx.wait();
        const midTotalReserves = await uToken.totalReserves();
        expect(midTotalReserves.sub(befTotalReserves).sub(addReservesAmount)).to.be.eq(0);
        const adminSigner = await ethers.provider.getSigner("0x0D25131E098DfB65746ecC3C527865A7bBA71886");
        const removeReservesTx = await uToken.connect(adminSigner).removeReserves(stakerAddress, addReservesAmount);
        await removeReservesTx.wait();
        const aftTotalReserves = await uToken.totalReserves();
        expect(aftTotalReserves.sub(befTotalReserves)).to.be.eq(0);
        await uToken.connect(stakerSigner).addReserves(addReservesAmount);
    });

    it("borrow and repay", async () => {
        const borrowAmount = parseUnits("500", 6);
        const borrowTx = await uToken.connect(borrowerSigner).borrow(borrowerAddress, borrowAmount);
        await borrowTx.wait();
        let borrowed = await uToken.getBorrowed(borrowerAddress);
        expect(borrowed).gte(borrowAmount.toString());
        const repayAmount = parseUnits("1000", 6);
        await usdc.connect(borrowerSigner).approve(uTokenAddress, repayAmount);
        const repayTx = await uToken.connect(borrowerSigner).repayBorrow(borrowerAddress, repayAmount);
        await repayTx.wait();
        borrowed = await uToken.getBorrowed(borrowerAddress);
        expect(borrowed).to.be.eq(0);
    });

    it("borrow and repay use aave adapter first", async () => {
        await assetManager.setWithdrawSequence([
            "0x2e89729353e075f46b40DA1D97fafE22CEBC0d9F",
            "0x95BB25c0A11347C8DE402904dce3Be628a4521C0"
        ]); //aaveV3Adapter, pureTokenAdapter
        const addReservesAmount = parseUnits("1000", 6);
        await usdc.connect(stakerSigner).approve(uTokenAddress, addReservesAmount.mul(2));
        const addReservesTx = await uToken.connect(stakerSigner).addReserves(addReservesAmount);
        await addReservesTx.wait();

        const borrowAmount = parseUnits("500", 6);
        const borrowTx = await uToken.connect(borrowerSigner).borrow(borrowerAddress, borrowAmount);
        await borrowTx.wait();
        let borrowed = await uToken.getBorrowed(borrowerAddress);
        expect(borrowed).gte(borrowAmount.toString());
        const repayAmount = parseUnits("1000", 6);
        await usdc.connect(borrowerSigner).approve(uTokenAddress, repayAmount);
        const repayTx = await uToken.connect(borrowerSigner).repayBorrow(borrowerAddress, repayAmount);
        await repayTx.wait();
        borrowed = await uToken.getBorrowed(borrowerAddress);
        expect(borrowed).to.be.eq(0);
    });

    it("delete fork", async () => {
        const TENDERLY_FORK_ACCESS_URL = `https://api.tenderly.co/api/v1/account/${process.env.TENDERLY_USER}/project/${process.env.TENDERLY_PROJECT}/fork/${forkId}`;
        await axios.delete(TENDERLY_FORK_ACCESS_URL, opts);
    });
});
