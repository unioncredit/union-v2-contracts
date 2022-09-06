import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import {isForked} from "../utils/fork";
import {getDeployer, fork} from "../utils";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts, DeployConfig} from "../../deploy";

describe("Test deployment configs", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let config: Omit<DeployConfig, "admin">;

    before(async function () {
        if(isForked()) await fork();

        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        config = getConfig();
        contracts = await deploy({...config, admin: deployerAddress}, deployer);
    });

    context("checking UserManager deployment config", () => {
        it("has the correct assetManager address", async () => {
            const assetManager = await contracts.userManager.assetManager();
            expect(assetManager).eq(contracts.assetManager.address);
        });
        it("has the correct union token address", async () => {
            const unionToken = await contracts.userManager.unionToken();
            expect(unionToken).eq(contracts.unionToken.address);
        });
        it("has the correct dai address", async () => {
            const stakingToken = await contracts.userManager.stakingToken();
            expect(stakingToken).eq(contracts.dai.address);
        });
        it("has the correct comptroller address", async () => {
            const comptroller = await contracts.userManager.comptroller();
            expect(comptroller).eq(contracts.comptroller.address);
        });
        it("has the correct admin", async () => {
            const isAdmin = await contracts.userManager.isAdmin(deployerAddress);
            expect(isAdmin).eq(true);
        });
        it("has the correct maxOverdue", async () => {
            const maxOverdue = await contracts.userManager.maxOverdueBlocks();
            expect(maxOverdue).eq(config.userManager.maxOverdue);
        });
        it("has the correct effectiveCount", async () => {
            const effectiveCount = await contracts.userManager.effectiveCount();
            expect(effectiveCount).eq(config.userManager.effectiveCount);
        });
        it("has the correct uToken adderss", async () => {
            const uToken = await contracts.userManager.uToken();
            expect(uToken).eq(contracts.uToken.address);
        });
    });

    context("checking Comptroller deployment config", () => {
        it("has the correct unionToken address", async () => {
            const rewardToken = await contracts.comptroller.unionToken();
            expect(rewardToken).eq(contracts.unionToken.address);
        });
        it("has the correct marketRegistry address", async () => {
            const marketRegistry = await contracts.comptroller.marketRegistry();
            expect(marketRegistry).eq(contracts.marketRegistry.address);
        });
        it("has the correct halfDecayPoint", async () => {
            const halfDecayPoint = await contracts.comptroller.halfDecayPoint();
            expect(halfDecayPoint).eq(config.comptroller.halfDecayPoint);
        });
    });

    context("checking AssetManager deployment config", () => {
        it("has the correct marketRegistry address", async () => {
            const marketRegistry = await contracts.assetManager.marketRegistry();
            expect(marketRegistry).eq(contracts.marketRegistry.address);
        });
    });

    context("checking PureTokenAdapter deployment config", () => {
        it("has the correct assetManager address", async () => {
            const assetManager = await contracts.adapters.pureToken.assetManager();
            expect(assetManager).eq(contracts.assetManager.address);
        });
    });

    context("checking UToken deployment config", () => {
        it("has the correct name", async () => {
            const name = await contracts.uToken.name();
            expect(name).eq(config.uToken.name);
        });
        it("has the correct symbol", async () => {
            const symbol = await contracts.uToken.symbol();
            expect(symbol).eq(config.uToken.symbol);
        });
        it("has the correct underlying token address", async () => {
            const underlying = await contracts.uToken.underlying();
            expect(underlying).eq(contracts.dai.address);
        });
        it("has the correct initialExchangeRateMantissa", async () => {
            const initialExchangeRateMantissa = await contracts.uToken.initialExchangeRateMantissa();
            expect(initialExchangeRateMantissa).eq(config.uToken.initialExchangeRateMantissa);
        });
        it("has the correct reserveFactorMantissa", async () => {
            const reserveFactorMantissa = await contracts.uToken.reserveFactorMantissa();
            expect(reserveFactorMantissa).eq(config.uToken.reserveFactorMantissa);
        });
        it("has the correct originationFee", async () => {
            const originationFee = await contracts.uToken.originationFee();
            expect(originationFee).eq(config.uToken.originationFee);
        });
        it("has the correct debtCeiling", async () => {
            const debtCeiling = await contracts.uToken.debtCeiling();
            expect(debtCeiling).eq(config.uToken.debtCeiling);
        });
        it("has the correct maxBorrow", async () => {
            const maxBorrow = await contracts.uToken.maxBorrow();
            expect(maxBorrow).eq(config.uToken.maxBorrow);
        });
        it("has the correct minBorrow", async () => {
            const minBorrow = await contracts.uToken.minBorrow();
            expect(minBorrow).eq(config.uToken.minBorrow);
        });
        it("has the correct overdueBlocks", async () => {
            const overdueBlocks = await contracts.uToken.overdueBlocks();
            expect(overdueBlocks).eq(config.uToken.overdueBlocks);
        });
        it("has the correct admin", async () => {
            const isAdmin = await contracts.uToken.isAdmin(deployerAddress);
            expect(isAdmin).eq(true);
        });
    });
});
