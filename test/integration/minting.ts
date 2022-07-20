import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Minting and redeeming uToken", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;

    const mintAmount = parseUnits("1000");

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        deployerAddress = await deployer.getAddress();
    });

    const beforeContext = async () => {
        contracts = await deploy({...config.main, admin: deployerAddress}, deployer);

        if ("mint" in contracts.dai) {
            const amount = parseUnits("1000000");
            await contracts.dai.mint(deployerAddress, amount);
            await contracts.dai.approve(contracts.uToken.address, amount);
        }
    };

    context("Minting uToken", () => {
        before(beforeContext);
        it("can mint and recieve uDAI", async () => {
            const balanceBefore = await contracts.uToken.balanceOf(deployerAddress);
            await contracts.uToken.mint(mintAmount);
            const balanceAfter = await contracts.uToken.balanceOf(deployerAddress);
            expect(balanceAfter.sub(balanceBefore)).eq(mintAmount);
        });
        it("can redeem uDAI for DAI", async () => {
            const balanceBefore = await contracts.dai.balanceOf(deployerAddress);
            await contracts.uToken.redeem(mintAmount);
            const balanceAfter = await contracts.dai.balanceOf(deployerAddress);
            expect(balanceAfter.sub(balanceBefore)).eq(mintAmount);
        });
    });
});
