import {expect} from "chai";
import {ethers} from "hardhat";
import {Signer} from "ethers";
import axios from "axios";
import {commify, formatUnits, parseUnits} from "ethers/lib/utils";
import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {getDai, roll} from "../../test/utils";

describe("Test on tenderly fork goerli", () => {
    let contracts: Contracts;
    let signer: Signer;
    let oldProvider: any;
    const {TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY} = process.env;
    const deployerAddress = "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4"; //admin
    const deployAndInitContracts = async () => {
        axios.create({
            baseURL: "https://api.tenderly.co/api/v1",
            headers: {
                "X-Access-Key": TENDERLY_ACCESS_KEY || "",
                "Content-Type": "application/json"
            }
        });

        const opts = {
            headers: {
                "X-Access-Key": TENDERLY_ACCESS_KEY
            }
        };

        const TENDERLY_FORK_API = `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`;
        const body = {
            network_id: "5",
            accounts: 120
        };

        const res = await axios.post(TENDERLY_FORK_API, body, opts);
        const forkId = res.data.simulation_fork.id;
        console.log(`forkId: ${forkId}`);
        const forkRPC = `https://rpc.tenderly.co/fork/${forkId}`;
        const provider = new ethers.providers.JsonRpcProvider(forkRPC);
        oldProvider = ethers.provider;
        ethers.provider = provider;

        signer = await ethers.provider.getSigner(deployerAddress);

        const amount = parseUnits("10000");
        contracts = await deploy({...getConfig(), admin: deployerAddress}, signer);
        await contracts.userManager.addMember(deployerAddress);
        await getDai(contracts.dai, signer, amount);
        await contracts.dai.approve(contracts.uToken.address, amount);
        await contracts.uToken.addReserves(amount);
        await contracts.uToken.setOriginationFee(0);
    };

    before(deployAndInitContracts);

    it("Test borrowing the max credit line when you have 100 stakers vouching for you", async () => {
        const signers = await ethers.getSigners();
        const amount = parseUnits("100");
        const borrower = signers[0];
        const borrowerAddress = await borrower.getAddress();

        let accounts: any = [];
        let accountAddresses: any = [];
        for (let i = 0; i < 100; i++) {
            const wallet = ethers.Wallet.createRandom();
            const accountSigner = await ethers.provider.getSigner(wallet.address);
            accountAddresses.push(wallet.address);
            accounts.push(accountSigner);
        }
        await ethers.provider.send("tenderly_setBalance", [
            accountAddresses,
            ethers.utils.hexValue(ethers.utils.parseUnits("1", "ether").toHexString())
        ]);

        for (let i = 0; i < accounts.length; i++) {
            console.log(i);
            const account = accounts[i];
            const accountAddress = await account.getAddress();
            console.log(accountAddress);
            await contracts.userManager.addMember(accountAddress);
            await getDai(contracts.dai, account, amount);
            await contracts.dai.connect(account).approve(contracts.userManager.address, amount);
            await contracts.userManager.connect(account).stake(amount);
            await contracts.userManager.connect(account).updateTrust(borrowerAddress, amount);
        }

        const creditLimit = await contracts.userManager.getCreditLimit(borrowerAddress);
        await contracts.uToken.connect(borrower).borrow(borrowerAddress, creditLimit);
        ethers.provider = oldProvider;
    });
});
