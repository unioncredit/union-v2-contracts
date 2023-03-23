import {expect} from "chai";
import {ethers} from "hardhat";
import {Signer, ContractFactory} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {isForked} from "../utils/fork";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";
import {roll, getDeployer, getDai, fork} from "../utils";
import {AdapterMock__factory} from "../../typechain-types";

describe("Users can lose their staking rewards ", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let adapter: any;

    before(async () => {
        if (isForked()) await fork();

        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
        const stakeAmount = await contracts.userManager.maxStakeAmount();
        await getDai(contracts.dai, deployer, stakeAmount);
        await contracts.dai.connect(deployer).approve(contracts.userManager.address, ethers.constants.MaxUint256);
        await contracts.userManager.addMember(deployerAddress);

        const AdapterMock: ContractFactory = new AdapterMock__factory(deployer);
        adapter = await AdapterMock.deploy();
        await contracts.assetManager.addAdapter(adapter.address);
        const firstAdapter = await contracts.assetManager.moneyMarkets(0);
        //priority deposit mock adapter
        await contracts.assetManager.setWithdrawSequence([adapter.address, firstAdapter]);
    });
    it("withraw reward when unstake all", async () => {
        const stakeAmount = parseUnits("100");
        await contracts.dai.approve(contracts.userManager.address, stakeAmount);
        await contracts.userManager.stake(stakeAmount);
        await roll(10);
        const balanceBefore = await contracts.unionToken.balanceOf(deployerAddress);
        //Take out all stakes
        await contracts.userManager.unstake(stakeAmount);
        const stakeInfo = await contracts.userManager.getStakeInfo(deployerAddress);
        expect(stakeInfo.effectiveStaked).eq(0);

        //Because the union balance is insufficient, the tokens are not transferred to the user but accumulated on accrued
        const balanceAfter = await contracts.unionToken.balanceOf(deployerAddress);
        expect(balanceAfter.sub(balanceBefore)).eq(0);
        let userInfo = await contracts.comptroller.users(deployerAddress, contracts.dai.address);
        expect(userInfo.accrued).gt(0);
        //Inject funds into comptroller
        await contracts.unionToken.mint(contracts.comptroller.address, parseUnits("100"));
        await contracts.userManager.withdrawRewards();
        const balanceFinal = await contracts.unionToken.balanceOf(deployerAddress);
        expect(balanceFinal.sub(balanceAfter)).gt(0);
        userInfo = await contracts.comptroller.users(deployerAddress, contracts.dai.address);
        expect(userInfo.accrued).eq(0);
    });
});
