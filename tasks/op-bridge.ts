import {task, types} from "hardhat/config";
import {Contract, ethers} from "ethers";
import {commify, formatEther, parseEther} from "ethers/lib/utils";
import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";
import {CrossChainMessenger, MessageStatus} from "@eth-optimism/sdk";

// UNION token transfers between L1 and L2 using the Optimism SDK

// Global variable because we need them almost everywhere
let crossChainMessenger: CrossChainMessenger;
let l1UnionContract: Contract, l2UnionContract: Contract; // UNION token contracts on L1 and L2
let signerAddr: string; // The address of the signer we use.

// Get signers on L1 and L2 (for the same address). Note that
// this address needs to have ETH on it, both on Optimism and
// Optimism Georli
const getSigners = async (privateKey: string, l1RpcUrl: string, l2RpcUrl: string) => {
    if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
        console.log("[!] Invalid format of private key");
        process.exit();
    }

    console.log({l1RpcUrl});
    console.log({l2RpcUrl});

    const l1RpcProvider = new ethers.providers.JsonRpcProvider(l1RpcUrl);
    const l2RpcProvider = new ethers.providers.JsonRpcProvider(l2RpcUrl);
    const l1Wallet = new ethers.Wallet(privateKey, l1RpcProvider);
    const l2Wallet = new ethers.Wallet(privateKey, l2RpcProvider);

    return [l1Wallet, l2Wallet];
};

// The ABI fragment for the contract.
const erc20ABI = [
    // balanceOf
    {
        constant: true,
        inputs: [{name: "_owner", type: "address"}],
        name: "balanceOf",
        outputs: [{name: "balance", type: "uint256"}],
        type: "function"
    }
];

const setup = async ({pk, l1Union, l2Union, l1RpcUrl, l2RpcUrl}) => {
    if (!l1RpcUrl || !l2RpcUrl) {
        console.log("[!] Invalid rpc url %s, %s", l1RpcUrl, l2RpcUrl);
        process.exit();
    }
    validateAddress(l1Union);
    validateAddress(l2Union);
    const [l1Signer, l2Signer] = await getSigners(pk, l1RpcUrl, l2RpcUrl);
    signerAddr = l1Signer.address;
    const l1ChainId = await l1Signer.getChainId();
    const l2ChainId = await l2Signer.getChainId();
    crossChainMessenger = new CrossChainMessenger({
        l1ChainId: l1ChainId,
        l2ChainId: l2ChainId,
        l1SignerOrProvider: l1Signer,
        l2SignerOrProvider: l2Signer
    });
    l1UnionContract = new ethers.Contract(l1Union, erc20ABI, l1Signer);
    l2UnionContract = new ethers.Contract(l2Union, erc20ABI, l2Signer);
    console.log({l1ChainId, l1Union: l1UnionContract.address});
    console.log({l2ChainId, l2Union: l2UnionContract.address});
};

const reportERC20Balances = async () => {
    console.log({l1Union: l1UnionContract.address});
    console.log({l2Union: l2UnionContract.address});
    const l1Balance = commify(formatEther(await l1UnionContract.balanceOf(signerAddr)));
    const l2Balance = commify(formatEther(await l2UnionContract.balanceOf(signerAddr)));
    console.log(`UNION on L1:${l1Balance}     UNION on L2:${l2Balance}`);
};

const validateAddress = (address: string) => {
    if (!ethers.utils.isAddress(address)) {
        console.log("[!] Invalid address %s", address);
        process.exit();
    }
};

task("op:deposit", "Deposit UNION tokens to Optimism")
    .addParam("l1RpcUrl", "L1 provider URL.", null, types.string)
    .addParam("l2RpcUrl", "L2 provider URL.", null, types.string)
    .addParam("l1Union", "Union token address on Mainnet", null, types.string)
    .addParam("l2Union", "Union token address on Optimism", null, types.string)
    .addParam("pk", "Private key to use for deployment", process.env.PRIVATE_KEY, types.string)
    .addParam("amount", "Amount of UNION to deposit (will be converted to wei)", null, types.string)
    .addOptionalParam("to", "Account to receive the deposit")
    .setAction(async (args: TaskArguments) => {
        const {l1Union, l2Union, l1RpcUrl, l2RpcUrl, pk, amount, to} = args;

        await setup({pk, l1Union, l2Union, l1RpcUrl, l2RpcUrl});

        const depositAmount = parseEther(amount);

        const recipient = to ? to : signerAddr;

        console.log("Deposit UNION to ${recipient} ...");
        await reportERC20Balances();
        const start = new Date().getTime();

        // Need the l2 address to know which bridge is responsible
        const allowanceResponse = await crossChainMessenger.approveERC20(l1Union, l2Union, depositAmount);
        await allowanceResponse.wait();
        console.log(`Allowance given by tx ${allowanceResponse.hash}`);
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);

        const response = await crossChainMessenger.depositERC20(l1Union, l2Union, depositAmount, {
            recipient
        });
        console.log(`Deposit transaction hash (on L1): ${response.hash}`);
        await response.wait();
        console.log("Waiting for status to change to RELAYED");
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
        await crossChainMessenger.waitForMessageStatus(response.hash, MessageStatus.RELAYED);

        await reportERC20Balances();
        console.log(`Deposit UNION took ${(new Date().getTime() - start) / 1000} seconds\n\n`);
    });

task("op:withdraw", "Withdraw UNION tokens from Optimism")
    .addParam("l1Union", "Union token address on Mainnet")
    .addParam("l2Union", "Union token address on Optimism")
    .addParam("pk", "Private key to use for deployment")
    .addParam("amount", "Amount of UNION to withdraw (will be converted to wei)")
    .setAction(async (args: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        const {l1Union, l2Union, l1RpcUrl, l2RpcUrl, pk, amount} = args;

        await setup({pk, l1Union, l2Union, l1RpcUrl, l2RpcUrl});

        const withdrawAmount = parseEther(amount);

        console.log("Withdraw UNION ...");
        const start = new Date().getTime();

        await reportERC20Balances();

        const response = await crossChainMessenger.withdrawERC20(l1Union, l2Union, withdrawAmount);
        console.log(`Transaction hash (on L2): ${response.hash}`);
        await response.wait();

        console.log("Waiting for status to change to IN_CHALLENGE_PERIOD");
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
        await crossChainMessenger.waitForMessageStatus(response.hash, MessageStatus.IN_CHALLENGE_PERIOD);
        console.log("In the challenge period, waiting for status READY_FOR_RELAY");
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
        await crossChainMessenger.waitForMessageStatus(response.hash, MessageStatus.READY_FOR_RELAY);
        console.log("Ready for relay, finalizing message now");
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
        await crossChainMessenger.finalizeMessage(response);
        console.log("Waiting for status to change to RELAYED");
        console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
        await crossChainMessenger.waitForMessageStatus(response, MessageStatus.RELAYED);
        await reportERC20Balances();
        console.log(`Withdraw UNION took ${(new Date().getTime() - start) / 1000} seconds\n\n\n`);
    });
