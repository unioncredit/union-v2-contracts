import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {getConfig} from "../../deploy/config";
import {getDai, getDeployer, prank, warp} from "../utils";
import deploy, {Contracts, DeployConfig} from "../../deploy";
import {AaveV3Adapter, ERC20__factory} from "../../typechain-types";

describe.fork("Aave V3 Adapter", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let aaveV3Adapter: AaveV3Adapter;
    let config: Omit<DeployConfig, "admin">;

    before(async function () {
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        config = getConfig();
        contracts = await deploy({...config, admin: deployerAddress}, deployer);

        const amount = parseUnits("10000");
        await getDai(contracts.dai, deployer, amount);

        aaveV3Adapter = contracts.adapters.aaveV3Adapter;
        await aaveV3Adapter.mapTokenToAToken(contracts.dai.address);
    };

    context("Deposit and Withdraw", () => {
        const amount = parseUnits("10");

        before(beforeContext);

        it("deposit DAI from the adapter", async () => {
            await contracts.dai.transfer(aaveV3Adapter.address, amount);
            await aaveV3Adapter.deposit(contracts.dai.address);

            const aTokenAddress = await aaveV3Adapter.tokenToAToken(contracts.dai.address);
            const aToken = ERC20__factory.connect(aTokenAddress, deployer);
            const bal = await aToken.balanceOf(aaveV3Adapter.address);

            expect(bal).eq(amount);
        });
        it("claim rewards from the adapter", async () => {
            await warp(60 * 60 * 24);
            await aaveV3Adapter.claimRewards(contracts.dai.address, deployerAddress);
            // Nothing to expect we can just check that this call doesn't fail
        });
        it("widthdraw DAI from the adapter", async () => {
            const signer = await prank(contracts.assetManager.address);

            const balBefore = await contracts.dai.balanceOf(deployerAddress);
            await aaveV3Adapter.connect(signer).withdrawAll(contracts.dai.address, deployerAddress);
            const balAfter = await contracts.dai.balanceOf(deployerAddress);

            expect(balAfter.sub(balBefore)).gte(amount);
        });
    });
});
