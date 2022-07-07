import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Owner/Admin permissions", () => {
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

    context("UserManager", () => {
        before(beforeContext);
        it("<FUNCTION> cannot be called by non owner");
    });

    context("UToken", () => {
        before(beforeContext);
        it("<FUNCTION> cannot be called by non owner");
    });
    
    context("Comptroller", () => {
        before(beforeContext);
        it("<FUNCTION> cannot be called by non owner");
    });
    
    context("AssetManager", () => {
        before(beforeContext);
        it("<FUNCTION> cannot be called by non owner");
    });
    
    context("PureTokenAdapter", () => {
        before(beforeContext);
        it("<FUNCTION> cannot be called by non owner");
    });
});
