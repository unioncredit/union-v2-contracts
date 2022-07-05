import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Test deployment configs", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
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
            const maxOverdue = await contracts.userManager.maxOverdue();
            expect(maxOverdue).eq(config.main.userManager.maxOverdue);
        });
        it("has the correct effectiveCount", async () => {
            const effectiveCount = await contracts.userManager.effectiveCount();
            expect(effectiveCount).eq(config.main.userManager.effectiveCount);
        });
    });
});
