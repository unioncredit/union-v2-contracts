import {ethers} from "ethers";
import {Provider} from "@ethersproject/abstract-provider";
import {task} from "hardhat/config";

import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";

import {
    Comptroller,
    Comptroller__factory,
    UserManagerOp,
    UserManagerOp__factory,
    OpUNION,
    OpUNION__factory,
    UErc20,
    UErc20__factory
} from "../typechain-types";

import {deployContract} from "../deploy/helpers";

import {getConfig} from "../deploy/config";

const debug = true;

const getDeployer = (privateKey: string, provider: Provider) => {
    if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
        console.log("[!] Invalid format of private key");
        process.exit();
    }

    return new ethers.Wallet(privateKey, provider);
};

task("patch:uerc20", "Deploy UErc20 implementation contract")
    .addParam("pk", "Private key to use for deployment")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        // ------------------------------------------------------
        // Setup
        // ------------------------------------------------------

        const privateKey = taskArguments.pk;
        const waitForBlocks = 1;

        const signer = getDeployer(privateKey, hre.ethers.provider);
        // console.log({signer});

        let deployer = signer;

        console.log(["[*] Deploying contracts", `    - deployer: ${await deployer.getAddress()}`].join("\n"));

        // ------------------------------------------------------
        // Deployment
        // ------------------------------------------------------

        await deployContract<UErc20>(new UErc20__factory(deployer), "UErc20", [], true, waitForBlocks);

        console.log("\n[*] Deployment complete\n");

        console.log("[*] Complete");
    });

task("deploy:unionToken", "Deploy UnionToken contracts")
    .addParam("pk", "Private key to use for deployment")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        const network = hre.network.name;
        const config = getConfig(network);
        const privateKey = taskArguments.pk;
        const waitForBlocks = 1;

        console.log("[*] Deployment config");
        console.log(config);

        const signer = getDeployer(privateKey, hre.ethers.provider);
        // console.log({signer});

        let deployer = signer;
        if (network == "hardhat") {
            const signerAddr = await signer.getAddress();
            await hre.ethers.getImpersonatedSigner(signerAddr);
            await hre.ethers.provider.send("hardhat_setBalance", [signerAddr, "0x56BC75E2D63100000"]);
        }

        console.log(
            [
                "[*] Deploying contracts",
                `    - waitForBlocks: ${waitForBlocks}`,
                `    - deployer: ${await deployer.getAddress()}`
            ].join("\n")
        );

        const opUnion = await deployContract<OpUNION>(
            new OpUNION__factory(signer),
            "OpUNION",
            [config.addresses.opL2Bridge, config.addresses.unionToken],
            debug,
            waitForBlocks
        );

        const opOwnerAddr = config.addresses.opOwner;
        console.log({opOwnerAddr});
        if (opOwnerAddr && (await opUnion.owner()) != opOwnerAddr) {
            // set UNION token's owner
            console.log(`    - Transfer UNION token's ownership to ${opOwnerAddr}`);
            const tx = await opUnion.transferOwnership(opOwnerAddr);
            await tx.wait(waitForBlocks);
        }
    });

task("patch:userManagerAndComptroller", "Update UserManager and Comptroller implementation contracts")
    .addParam("pk", "Private key to use for deployment")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        const privateKey = taskArguments.pk;
        const waitForBlocks = 1;

        const signer = getDeployer(privateKey, hre.ethers.provider);

        const comptroller = await deployContract<Comptroller>(
            new Comptroller__factory(signer),
            "Comptroller",
            [],
            debug,
            waitForBlocks
        );

        const userManager = await deployContract<UserManagerOp>(
            new UserManagerOp__factory(signer),
            "UserManagerOp",
            [],
            debug,
            waitForBlocks
        );
    });

task("revert:userManagerAndComptroller", "Revert UserManager and Comptroller implementation contracts")
    .addParam("pk", "Private key to use for deployment")
    .setAction(async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {});
