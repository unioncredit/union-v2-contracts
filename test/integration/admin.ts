import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Owner/Admin permissions", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let nonAdmin: Signer;
    let contracts: Contracts;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        nonAdmin = signers[1];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);
    };

    context("UserManager", () => {
        before(beforeContext);
        it("setMaxStakeAmount cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setMaxStakeAmount(0);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
        it("setUToken cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setUToken(deployerAddress);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
        it("setNewMemberFee cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setNewMemberFee(0);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
        it("setMaxOverdueBlocks cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setMaxOverdueBlocks(0);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
        it("setEffectiveCount cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setEffectiveCount(0);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
        it("addMember cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).addMember(deployerAddress);
            await expect(resp).to.be.revertedWith("Controller: not admin");
        });
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
