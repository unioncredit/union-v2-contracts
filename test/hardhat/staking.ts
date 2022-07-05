import {expect} from "chai";
import {Signer} from "ethers";
import {parseUnits} from "ethers/lib/utils";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Staking and unstaking", () => {
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

        if ("mint" in contracts.dai) {
            for (const signer of signers) {
                const address = await signer.getAddress();
                const amount = parseUnits("10000000");
                await contracts.dai.mint(address, amount);
                await contracts.dai.approve(contracts.userManager.address, amount);
            }
        }
    };

    context("staking and unstaking as a non member", () => {
        before(beforeContext);
        it("cannot stake more than limit", async () => {
            const maxStake = await contracts.userManager.maxStakeAmount();
            await contracts.userManager.stake(maxStake);
        });
        it("transfers underlying token to assetManager");
        it("staking updates total staked and user staked");
        it("cannot unstake more than staked");
        it("unstaking transfers underlying token from assetManager");
        it("unstaking updates total staked and user staked");
    });

    context("staking rewards", () => {
        before(beforeContext);
        it("withdraw rewards from comptroller");
        it("withdraw rewards when staking");
        it("large staker has more rewards than small staker");
        it("staker with frozen balance gets less rewards");
        it("staker with locked balance gets more rewards");
    });

    context("stake underwrites borrow", () => {
        before(beforeContext);
        it("cannot unstake when locked");
    });
});
