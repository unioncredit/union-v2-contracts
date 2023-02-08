import * as fs from "fs";
import * as path from "path";
import {ethers} from "ethers";
import {Interface} from "ethers/lib/utils";
import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";

import deploy, {Contracts} from "../deploy/index";
import deployOP, {OpContracts} from "../deploy/optimism";
import {getConfig} from "../deploy/config";
import {deployContract} from "../deploy/helpers";
import {
    UnionLens,
    UnionLens__factory,
    OpUNION,
    OpUNION__factory,
    OpOwner,
    OpOwner__factory,
    OpConnector,
    OpConnector__factory
} from "../typechain-types";

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

const deploymentOpToAddresses = (contracts: OpContracts): {[key: string]: string | {[key: string]: string}} => {
    return {
        opUnion: contracts.opUnion.address,
        opOwner: contracts.opOwner.address,
        userManager: contracts.userManager.address,
        uToken: contracts.uToken.address,
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

const getDeployer = (privateKey: string, provider: ethers.providers.BaseProvider) => {
    if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
        console.log("[!] Invalid format of private key");
        process.exit();
    }

    return new ethers.Wallet(privateKey, provider);
};

task("deploy:opConnector", "Deploy L1 connector for Optimism UNION token")
    .addParam("pk", "Private key to use for deployment")
    .addParam("confirmations", "How many confirmations to wait for")
    // .addParam("members", "Initial union members")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        // ------------------------------------------------------
        // Setup
        // ------------------------------------------------------
        const config = getConfig();
        console.log("[*] Deployment config");
        console.log(config);

        const privateKey = taskArguments.pk;
        const deployer = getDeployer(privateKey, hre.ethers.provider);

        const waitForBlocks = taskArguments.confirmations;

        console.log(
            [
                "[*] Deploying contracts",
                `    - waitForBlocks: ${waitForBlocks}`,
                `    - deployer: ${await deployer.getAddress()}`
            ].join("\n")
        );

        // get deploy directory
        const dir = path.resolve(__dirname, "../deployments", hre.network.name);
        if (!fs.existsSync(dir)) {
            console.log("[!] Cannot find deployment file");
            process.exit();
        }

        // read deployment file
        const deploymentFile = path.resolve(dir, "deployment.json");

        let deployedContracts;
        try {
            const data = fs.readFileSync(deploymentFile, {encoding: "utf8"});
            deployedContracts = JSON.parse(data);
        } catch (err) {
            console.log({err});
            process.exit();
        }

        console.log(deployedContracts);

        // validate addresses
        if (
            !deployedContracts.comptroller ||
            !config.addresses.unionToken ||
            !config.addresses.opUnion ||
            !config.addresses.opL1Bridge
        ) {
            console.log("[!] Required address null");
            process.exit();
        }

        const opConector = await deployContract<OpConnector>(
            new OpConnector__factory(deployer),
            "opConnector",
            [
                config.addresses.unionToken,
                config.addresses.opUnion,
                deployedContracts.comptroller,
                config.addresses.opL1Bridge
            ],
            true,
            waitForBlocks
        );
        console.log("\n[*] Deployment complete\n");

        // save deployment
        const connDeploymentPath = path.resolve(dir, "connector.json");
        fs.writeFileSync(
            connDeploymentPath,
            JSON.stringify(
                {
                    opConnector: opConector.address
                },
                null,
                2
            )
        );
        console.log(`    - deployment: ${connDeploymentPath}`);

        console.log("[*] Complete");
    });

task("deploy:op", "Deploy Union V2 on Optimism")
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

        console.log("[*] Deployment config");
        console.log(config);

        const deployer = getDeployer(privateKey, hre.ethers.provider);

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

        const deployment = await deployOP({admin: deployer.address, ...config}, deployer, true, waitForBlocks);
        const deploymentAddresses = deploymentOpToAddresses(deployment);

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
        const iface = new Interface([`function addMember(address) external`]);
        for (const member of members) {
            console.log(`    - ${member}`);
            const encoded = iface.encodeFunctionData("addMember(address)", [member]);
            const tx = await deployment.opOwner.execute(deployment.userManager.address, 0, encoded);
            await tx.wait(waitForBlocks);
        }

        if (config?.addresses?.opAdminAddress) {
            const tx = await deployment.opOwner.transferAdmin(config.addresses.opAdminAddress);
            await tx.wait(waitForBlocks);
        }

        console.log("[*] Complete");
    });

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

        console.log("[*] Deployment config");
        console.log(config);

        const deployer = getDeployer(privateKey, hre.ethers.provider);

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

        const deployment = await deploy({admin: deployer.address, ...config}, deployer, true, waitForBlocks);
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
            const tx = await deployment.userManager.addMember(member);
            await tx.wait(waitForBlocks);
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

        const deployer = getDeployer(privateKey, hre.ethers.provider);

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
