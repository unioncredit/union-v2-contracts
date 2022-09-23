import * as fs from "fs";
import * as path from "path";
import {ethers} from "ethers";
import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";

import deploy, {Contracts} from "../deploy/index";
import {getConfig} from "../deploy/config";
import {deployContract} from "../deploy/helpers";
import {UnionLens, UnionLens__factory} from "../typechain-types";

const deploymentToAddresses = (contracts: Contracts): {[key: string]: string | {[key: string]: string}} => {
    return {
        userManager: contracts.userManager.address,
        uToken: contracts.uToken.address,
        unionToken: contracts.unionToken.address,
        marketRegistry: contracts.marketRegistry.address,
        fixedRateInterestModel: contracts.fixedInterestRateModel.address,
        comptroller: contracts.comptroller.address,
        assetManager: contracts.assetManager.address,
        dai: contracts.dai.address,
        adapters: {
            pureToken: contracts.adapters.pureToken?.address || ethers.constants.AddressZero,
            aaveV3Adapter: contracts.adapters.aaveV3Adapter?.address || ethers.constants.AddressZero
        }
    };
};

task("deploy", "Deploy Union V2 contracts")
    .addParam("pk", "Private key to use for deployment")
    .addParam("confirmations", "How many confirmations to wait for")
    .addParam("members", "Initial union members")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        // ------------------------------------------------------
        // Setup
        // ------------------------------------------------------

        const config = getConfig();
        const privateKey = taskArguments.pk;
        const waitForBlocks = taskArguments.confirmations;

        if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
            console.log("[!] Invalid format of private key");
            process.exit();
        }

        console.log("[*] Deployment config");
        console.log(config);

        const deployer = new ethers.Wallet(privateKey, hre.ethers.provider);

        console.log(
            [
                "[*] Deploying contracts",
                `    - waitForBlocks: ${waitForBlocks}`,
                `    - deployer: ${await deployer.getAddress()}`
            ].join("\n")
        );

        // ------------------------------------------------------
        // Deployment
        // ------------------------------------------------------

        const deployment = await deploy({...config, admin: deployer.address}, deployer, true, waitForBlocks);
        const deploymentAddresses = deploymentToAddresses(deployment);

        console.log("\n[*] Deployment complete\n");

        // ------------------------------------------------------
        // Save deployment and config
        // ------------------------------------------------------

        console.log("[*] Saving deployment addresses");

        // create save directory
        const dir = path.resolve(__dirname, "../deployments", hre.network.name);
        !fs.existsSync(dir) && fs.mkdirSync(dir);

        // save deployment
        const saveDeploymentPath = path.resolve(dir, "deployment.json");
        fs.writeFileSync(saveDeploymentPath, JSON.stringify(deploymentAddresses, null, 2));
        console.log(`    - deployment: ${saveDeploymentPath}`);

        // save config
        const saveConfigPath = path.resolve(dir, "config.json");
        fs.writeFileSync(saveConfigPath, JSON.stringify(config, null, 2));
        console.log(`    - config: ${saveConfigPath}`);

        // ------------------------------------------------------
        // Add initial members
        // ------------------------------------------------------

        console.log("[*] Adding initial members");
        const members = taskArguments.members.split(",");
        for (const member of members) {
            console.log(`    - ${member}`);
            await deployment.userManager.addMember(member);
        }

        console.log("[*] Complete");
    });

task("deploy:lens", "Deploy Union lens contract")
    .addParam("pk", "Private key to use for deployment")
    .addParam("confirmations", "How many confirmations to wait for")
    .addParam("marketregistry", "Market registry contract address")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        // ------------------------------------------------------
        // Setup
        // ------------------------------------------------------

        const privateKey = taskArguments.pk;
        const marketRegistry = taskArguments.marketregistry;
        const waitForBlocks = taskArguments.confirmations;

        if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
            console.log("[!] Invalid format of private key");
            process.exit();
        }

        const deployer = new ethers.Wallet(privateKey, hre.ethers.provider);

        console.log(
            [
                "[*] Deploying contracts",
                `    - marketRegistry: ${marketRegistry}`,
                `    - deployer: ${await deployer.getAddress()}`
            ].join("\n")
        );

        // ------------------------------------------------------
        // Deployment
        // ------------------------------------------------------

        const lens = await deployContract<UnionLens>(
            new UnionLens__factory(deployer),
            "unionLens",
            [marketRegistry],
            true,
            waitForBlocks
        );

        console.log("\n[*] Deployment complete\n");

        // ------------------------------------------------------
        // Save deployment and config
        // ------------------------------------------------------

        console.log("[*] Saving deployment addresses");

        // create save directory
        const dir = path.resolve(__dirname, "../deployments", hre.network.name);
        !fs.existsSync(dir) && fs.mkdirSync(dir);

        // save deployment
        const saveDeploymentPath = path.resolve(dir, "lens.json");
        fs.writeFileSync(saveDeploymentPath, JSON.stringify({lens: lens.address}, null, 2));
        console.log(`    - deployment: ${saveDeploymentPath}`);

        console.log("[*] Complete");
    });
