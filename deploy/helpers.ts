import {Contract, ContractFactory} from "ethers";
import {formatUnits, Interface} from "ethers/lib/utils";

const DEBUG_DEFAULT = false;

export async function deployProxy<T extends Contract>(
    contractFactory: ContractFactory,
    contractName: string,
    initialize: {
        signature: string;
        args: Array<unknown>;
    },
    debug = DEBUG_DEFAULT
) {
    // Intentionally doing this here to avoid the hardhat already loaded error
    const {upgrades} = require("hardhat");

    const initFnName = initialize.signature.replace(/\((.+)?\)/, "");
    const iface = new Interface([`function ${initialize.signature} external`]);
    const encoded = iface.encodeFunctionData(initFnName, initialize.args || []);

    if (debug) {
        console.log(
            [
                "[*] Encoding initializer args",
                `    - name: ${initFnName}`,
                `    - args: ${initialize.args.toString()}`,
                `    - encoded: ${encoded}`
            ].join("\n")
        );
    }

    const proxy = await upgrades.deployProxy(contractFactory, initialize.args || [], {
        kind: "uups",
        initializer: initFnName
    });

    // TODO: we should raise a PR to be able to pass in nConfirmations to deployed
    const resp = await proxy.deployed();

    if (debug) {
        console.log(
            [
                `[*] Deployed proxy ${contractName}`,
                `    - hash: ${resp.deployTransaction.hash}`,
                `    - from: ${resp.deployTransaction.from}`
            ].join("\n")
        );
    }

    return {proxy: proxy as any as T};
}

export async function deployContract<T extends Contract>(
    contractFactory: ContractFactory,
    contractName: string,
    constructorArgs: Array<unknown> = [],
    debug = DEBUG_DEFAULT,
    waitForBlocks: number | undefined = undefined
): Promise<T> {
    const contract = await contractFactory.deploy(...constructorArgs);

    if (debug) {
        console.log(
            [
                `[*] Deploying ${contractName}`,
                `    - hash: ${contract.deployTransaction.hash}`,
                `    - from: ${contract.deployTransaction.from}`,
                `    - gas price: ${contract.deployTransaction.gasPrice?.toNumber() || 0 / 1e9} Gwei`
            ].join("\n")
        );
    }

    const receipt = await contract.deployTransaction.wait(waitForBlocks);
    const txCost = receipt.gasUsed.mul(contract.deployTransaction.gasPrice || 0);
    const abiEncodedConstructorArgs = contract.interface.encodeDeploy(constructorArgs);

    if (debug) {
        console.log(
            [
                `[*] Deployed ${contractName} to ${contract.address}`,
                `    - block: ${receipt.blockNumber}`,
                `    - gas used: ${receipt.gasUsed}`,
                `    - gas cost: ${formatUnits(txCost)} ETH`,
                `    - encoded args: ${abiEncodedConstructorArgs.slice(2)}`
            ].join("\n")
        );
    }

    return contract as T;
}
