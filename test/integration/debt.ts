import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Writing off member debt", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
    };

    context("Staker writing off own locked stake", () => {
        before(beforeContext);
        it("borrower is not overdue");
        it("borrower is overdue");
        it("write off entire debt");
    });

    context("Public writing off debt", () => {
        before(beforeContext);
        it("cannot if not overdue");
        it("cannot if grace period has not passed");
        it("public can write off debt");
    });
});
