import {Contract, ethers} from "ethers";
import {commify, formatEther, parseEther} from "ethers/lib/utils";
import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";
import {CrossChainMessenger, MessageStatus} from "@eth-optimism/sdk";

// UNION token transfers between L1 and L2 using the Optimism SDK

const L1_RPC = `https://eth-goerli.g.alchemy.com/v2/${process.env.GOERLI_ALCHEMY_KEY}`;
const L2_RPC = `https://goerli.optimism.io`; //`https://opt-goerli.g.alchemy.com/v2/${process.env.OPTIMISM_GOERLI_ALCHEMY_KEY}`

// Contract addresses for UNION tokens
const unionTokenAddrs = {
    l1Addr: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
    l2Addr: "0x04622FDe6a7C0B19Ff7748eC8882870367530074"
};

// Global variable because we need them almost everywhere
let crossChainMessenger: CrossChainMessenger;
let l1Union: Contract, l2Union: Contract; // UNION token contracts on L1 and L2
let signerAddr: string; // The address of the signer we use.

// Get signers on L1 and L2 (for the same address). Note that
// this address needs to have ETH on it, both on Optimism and
// Optimism Georli
const getSigners = async (privateKey: string) => {
    if (!privateKey.match(/^[A-Fa-f0-9]{1,64}$/)) {
        console.log("[!] Invalid format of private key");
        process.exit();
    }

    console.log({L1_RPC});
    console.log({L2_RPC});

    const l1RpcProvider = new ethers.providers.JsonRpcProvider(L1_RPC);
    const l2RpcProvider = new ethers.providers.JsonRpcProvider(L2_RPC);
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

const setup = async (privateKey: string) => {
    const [l1Signer, l2Signer] = await getSigners(privateKey);
    signerAddr = l1Signer.address;
    crossChainMessenger = new CrossChainMessenger({
        l1ChainId: 5, // Goerli value, 1 for mainnet
        l2ChainId: 420, // Goerli value, 10 for mainnet
        l1SignerOrProvider: l1Signer,
        l2SignerOrProvider: l2Signer
    });
    l1Union = new ethers.Contract(unionTokenAddrs.l1Addr, erc20ABI, l1Signer);
    l2Union = new ethers.Contract(unionTokenAddrs.l2Addr, erc20ABI, l2Signer);
    console.log({l1Union: l1Union.address});
    console.log({l2Union: l2Union.address});
};

const reportERC20Balances = async () => {
    const l1Balance = commify(formatEther(await l1Union.balanceOf(signerAddr)));
    const l2Balance = commify(formatEther(await l2Union.balanceOf(signerAddr)));
    console.log(`UNION on L1:${l1Balance}     UNION on L2:${l2Balance}`);
};

const deposit = async (signerPk, depositAmount, recipientAddr?: string) => {
    await setup(signerPk);

    const amount = parseEther(depositAmount);

    const recipient = recipientAddr ? recipientAddr : signerAddr;

    console.log("Deposit UNION ...");
    await reportERC20Balances();
    const start = new Date().getTime();

    // Need the l2 address to know which bridge is responsible
    const allowanceResponse = await crossChainMessenger.approveERC20(
        unionTokenAddrs.l1Addr,
        unionTokenAddrs.l2Addr,
        amount
    );
    await allowanceResponse.wait();
    console.log(`Allowance given by tx ${allowanceResponse.hash}`);
    console.log(`\tMore info: https://goerli.etherscan.io/tx/${allowanceResponse.hash}`);
    console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);

    const response = await crossChainMessenger.depositERC20(unionTokenAddrs.l1Addr, unionTokenAddrs.l2Addr, amount, {
        recipient
    });
    console.log(`Deposit transaction hash (on L1): ${response.hash}`);
    console.log(`\tMore info: https://goerli.etherscan.io/tx/${response.hash}`);
    await response.wait();
    console.log("Waiting for status to change to RELAYED");
    console.log(`Time so far ${(new Date().getTime() - start) / 1000} seconds`);
    await crossChainMessenger.waitForMessageStatus(response.hash, MessageStatus.RELAYED);

    await reportERC20Balances();
    console.log(`Deposit UNION took ${(new Date().getTime() - start) / 1000} seconds\n\n`);
};

task("op:depositTo", "Deposit UNION tokens to Optimism")
    .addParam("pk", "Private key to use for deployment")
    .addParam("amount", "Amount of UNION to deposit (will be converted to wei)")
    .addParam("recipient", "Account to receive the deposit")
    .setAction(async (args: TaskArguments) => {
        await deposit(args.pk, args.amount, args.recipient);
    });

task("op:deposit", "Deposit UNION tokens to Optimism")
    .addParam("pk", "Private key to use for deployment")
    .addParam("amount", "Amount of UNION to deposit (will be converted to wei)")
    .setAction(async (args: TaskArguments) => {
        await deposit(args.pk, args.amount);
    });

task("op:withdraw", "Withdraw UNION tokens from Optimism")
    .addParam("pk", "Private key to use for deployment")
    .addParam("amount", "Amount of UNION to withdraw (will be converted to wei)")
    .setAction(async (args: TaskArguments, hre: HardhatRuntimeEnvironment) => {
        await setup(args.pk);

        const amount = parseEther(args.amount);

        console.log("Withdraw UNION ...");
        const start = new Date().getTime();

        await reportERC20Balances();

        const response = await crossChainMessenger.withdrawERC20(
            unionTokenAddrs.l1Addr,
            unionTokenAddrs.l2Addr,
            amount
        );
        console.log(`Transaction hash (on L2): ${response.hash}`);
        console.log(`\tFor more information: https://goerli-optimism.etherscan.io/tx/${response.hash}`);
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
