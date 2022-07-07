import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Minting and redeeming uToken", () => {
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

    context("Minting uToken", () => {
        before(beforeContext);
        it("can mint and recieve uDAI");
        it("can redeem uDAI for DAI")
    });
});
