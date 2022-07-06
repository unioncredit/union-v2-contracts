import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Vouching", () => {
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

        for (const signer of signers) {
            const address = await signer.getAddress();
            await contracts.userManager.addMember(address);
        }
    };

    context("Adjusting trust", () => {
        before(beforeContext);
        it("cannot vouch for self");
        it("can only be called by a member");
        it("cannot increase vouch when updating trust with no stake");
        it("increase vouch when updating trust with stake");
        it("can update trust on already trusted member");
        it("cannot reduce trust with locked amount");
    });

    context("Cancel vouch", () => {
        before(beforeContext);
        it("only staker or borrower can cancel vouch");
        it("cannot cancel a vouch with locked amount");
        it("cancelling vouch removes member from vouchers array and correctly re-indexes");
    });
});
