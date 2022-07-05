import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";
import {UserManager} from "../../typechain-types";

describe("UserManager.sol", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;

    let userManager: UserManager;
    let contracts: Contracts;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
        userManager = contracts.userManager;
    };

    context("checking deployment config", () => {
        before(beforeContext);
        it("has the correct assetManager address", async () => {
            const assetManager = await userManager.assetManager();
            expect(assetManager).eq(contracts.assetManager.address);
        });
        it("has the correct union token address", async () => {
            const unionToken = await userManager.unionToken();
            expect(unionToken).eq(contracts.unionToken.address);
        });
        it("has the correct dai address", async () => {
            const stakingToken = await userManager.stakingToken();
            expect(stakingToken).eq(contracts.dai.address);
        });
        it("has the correct comptroller address", async () => {
            const comptroller = await userManager.comptroller();
            expect(comptroller).eq(contracts.comptroller.address);
        });
        it("has the correct admin", async () => {
            const isAdmin = await userManager.isAdmin(deployerAddress);
            expect(isAdmin).eq(true);
        });
        it("has the correct maxOverdue", async () => {
            const maxOverdue = await userManager.maxOverdue();
            expect(maxOverdue).eq(config.main.userManager.maxOverdue);
        });
        it("has the correct effectiveCount", async () => {
            const effectiveCount = await userManager.effectiveCount();
            expect(effectiveCount).eq(config.main.userManager.effectiveCount);
        });
    });
});
