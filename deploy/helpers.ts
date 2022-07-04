import {Contract, ContractFactory, Signer} from "ethers";
import {formatUnits, Interface} from "ethers/lib/utils";
import {UUPSProxy, UUPSProxy__factory} from "../typechain-types";

const AddressZero = "0x0000000000000000000000000000000000000000";

export async function deployProxy<T extends Contract>(
    signer: Signer,
    contractFactory: ContractFactory,
    contractName: string,
    initialize: {
        signature: string;
        args: Array<unknown>;
    },
    debug = true
) {
    const implementation = await deployContract<T>(contractFactory, `Proxy:Implementation:${contractName}`, [], debug);

    const initFnName = initialize.signature.replace(/\((.+)?\)/, "");
    const iface = new Interface([initialize.signature]);
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

    const constructorArgs = [implementation, AddressZero, encoded];
    const proxy = await deployContract<UUPSProxy>(
        new UUPSProxy__factory(signer),
        `Proxy:${contractName}`,
        constructorArgs,
        debug
    );

    return {proxy, implementation};
}

export async function deployContract<T extends Contract>(
    contractFactory: ContractFactory,
    contractName: string,
    constructorArgs: Array<unknown> = [],
    debug = true,
    waitForBlocks = undefined
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
