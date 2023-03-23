import {expect} from "chai";

import {Signer, ContractFactory} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";

import {PureTokenAdapter, PureTokenAdapter__factory} from "../../typechain-types";

describe("Market adapter removal corrupts withdraw sequence", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    before(async function () {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        const PureTokenAdapter: ContractFactory = new PureTokenAdapter__factory(deployer);
        //Add 3 test adapters
        let i = 0;
        while (i < 3) {
            const pureTokenAdapter = await PureTokenAdapter.deploy();
            await contracts.assetManager.addAdapter(pureTokenAdapter.address);
            i++;
        }
    });

    it("The original order will not be changed after deleting the adapter", async () => {
        let moneyMarkets: any = [];
        let withdrawSeq: any = [];
        let i = 0;
        while (true) {
            try {
                const market = await contracts.assetManager.moneyMarkets(i);
                moneyMarkets.push(market);
                const withdrawMarket = await contracts.assetManager.withdrawSeq(i);
                withdrawSeq.push(withdrawMarket);
            } catch (error) {
                break;
            }
            i++;
        }
        console.log(`moneyMarkets: `, moneyMarkets);
        console.log(`withdrawSeq: `, withdrawSeq);

        //Make sure the data is valid
        expect(moneyMarkets.length).eq(withdrawSeq.length);
        expect(moneyMarkets.length).gt(0);
        const removeIndex = parseInt((moneyMarkets.length / 2).toString());
        await contracts.assetManager.removeAdapter(moneyMarkets[removeIndex]);
        let newMoneyMarkets: any = [];
        let newWithdrawSeq: any = [];
        i = 0;
        while (true) {
            try {
                const market = await contracts.assetManager.moneyMarkets(i);
                newMoneyMarkets.push(market);
                const withdrawMarket = await contracts.assetManager.withdrawSeq(i);
                newWithdrawSeq.push(withdrawMarket);
            } catch (error) {
                break;
            }
            i++;
        }
        console.log(`newMoneyMarkets: `, newMoneyMarkets);
        console.log(`newWithdrawSeq: `, newWithdrawSeq);
        //Verify that the sequence is correct
        expect(moneyMarkets.length - 1).eq(newMoneyMarkets.length);
        expect(withdrawSeq.length - 1).eq(newWithdrawSeq.length);
        for (let i = 0; i < newMoneyMarkets.length; i++) {
            if (removeIndex > i) {
                expect(moneyMarkets[i]).eq(newMoneyMarkets[i]);
            } else {
                expect(moneyMarkets[i + 1]).eq(newMoneyMarkets[i]);
            }
        }
        for (let i = 0; i < newWithdrawSeq.length; i++) {
            if (removeIndex > i) {
                expect(withdrawSeq[i]).eq(newWithdrawSeq[i]);
            } else {
                expect(withdrawSeq[i + 1]).eq(newWithdrawSeq[i]);
            }
        }
    });
});
