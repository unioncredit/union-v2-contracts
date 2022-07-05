import {expect} from "chai";
import {ethers} from "hardhat";
import deploy from "../../deploy";
import config from "../../deploy/config";

describe("UserManager.sol", () => {
    before(async function () {
        const signers = await ethers.getSigners();
        const deployer = signers[0];
        const deployerAddress = await deployer.getAddress();

        const resp = await deploy({...config.main, admin: deployerAddress}, deployer);

        console.log(resp);
    });

    it("empty", () => {
        expect(true).eq(true);
    });
});
