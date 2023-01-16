import "./testSetup";

import {expect} from "chai";
import {ethers} from "hardhat";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {isForked} from "../utils/fork";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";
import {getDeployer, getDai, fork} from "../utils";

describe("Depositing and withdrawing", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    const beforeContext = async () => {
        if (isForked()) await fork();

        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
    };

    beforeEach(beforeContext);

    it("deposit and withdraw as usermanager", async () => {
        const stakeAmount = parseUnits("100");
        await getDai(contracts.dai, deployer, stakeAmount);
        await contracts.dai.connect(deployer).approve(contracts.userManager.address, ethers.constants.MaxUint256);
        let bal = await contracts.dai.balanceOf(contracts.assetManager.address);
        expect(bal).eq(0);
        await contracts.userManager.stake(stakeAmount);
        bal = await contracts.dai.balanceOf(contracts.assetManager.address);
        expect(bal).eq(stakeAmount);

        await contracts.userManager.unstake(stakeAmount);
        bal = await contracts.dai.balanceOf(contracts.assetManager.address);
        expect(bal).eq(0);
    });

    it("deposit and withdraw with money markets", async () => {
        const stakeAmount = parseUnits("100");
        await getDai(contracts.dai, deployer, stakeAmount);
        await contracts.dai.connect(deployer).approve(contracts.userManager.address, ethers.constants.MaxUint256);

        await contracts.adapters.pureToken.setFloor(contracts.dai.address, parseUnits("10"));
        let bal = await contracts.dai.balanceOf(contracts.adapters.pureToken.address);
        expect(bal).eq(0);
        await contracts.userManager.stake(stakeAmount);
        bal = await contracts.dai.balanceOf(contracts.adapters.pureToken.address);
        expect(bal).eq(stakeAmount);

        await contracts.userManager.unstake(stakeAmount);
        bal = await contracts.dai.balanceOf(contracts.adapters.pureToken.address);
        expect(bal).eq(0);
    });
});
