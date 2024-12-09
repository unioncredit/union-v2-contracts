import {ethers} from "ethers";
import {Provider} from "@ethersproject/abstract-provider";
import {task} from "hardhat/config";

import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";

import {UErc20, UErc20__factory} from "../typechain-types";

import {deployContract} from "../deploy/helpers";

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
