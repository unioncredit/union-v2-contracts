import "./testSetup";

import {expect} from "chai";
import {Signer} from "ethers";

import deploy, {Contracts} from "../../deploy";
import {getConfig} from "../../deploy/config";
import {fork, getDeployer, getSigners} from "../utils";
import {isForked} from "../utils/fork";
import error from "../utils/error";

describe("Owner/Admin permissions", () => {
    let signers: Signer[];
    let deployer: Signer;
    let deployerAddress: string;
    let nonAdmin: Signer;
    let contracts: Contracts;

    const beforeContext = async () => {
        if (isForked()) await fork();

        signers = await getSigners();
        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        nonAdmin = signers[1];

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);
    };

    context("UserManager", () => {
        before(beforeContext);
        it("setMaxStakeAmount cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setMaxStakeAmount(1);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setUToken cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setUToken(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setNewMemberFee cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setNewMemberFee(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setMaxOverdueBlocks cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setMaxOverdueBlocks(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setEffectiveCount cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).setEffectiveCount(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("addMember cannot be called by non owner", async () => {
            const resp = contracts.userManager.connect(nonAdmin).addMember(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
    });

    context("UToken", () => {
        before(beforeContext);
        it("setAssetManager cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setAssetManager(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setUserManager cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setUserManager(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setOriginationFee cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setOriginationFee(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setDebtCeiling cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setDebtCeiling(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setMinBorrow cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setMinBorrow(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setMaxBorrow cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setMaxBorrow(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setOverdueBlocks cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setOverdueBlocks(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setInterestRateModel cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setInterestRateModel(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setReserveFactor cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).setReserveFactor(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("removeReserves cannot be called by non owner", async () => {
            const resp = contracts.uToken.connect(nonAdmin).removeReserves(deployerAddress, 0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
    });

    context("Comptroller", () => {
        before(beforeContext);
        it("setHalfDecayPoint cannot be called by non owner", async () => {
            const resp = contracts.comptroller.connect(nonAdmin).setHalfDecayPoint(0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
    });

    context("AssetManager", () => {
        before(beforeContext);
        it("setMarketRegistry cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).setMarketRegistry(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("addToken cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).addToken(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("removeToken cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).removeToken(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("addAdapter cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).addAdapter(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("removeAdapter cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).removeAdapter(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("approveAllMarketsMax cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).approveAllMarketsMax(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("approveAllTokensMax cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).approveAllTokensMax(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setWithdrawSequence cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).setWithdrawSequence([]);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("rebalance cannot be called by non owner", async () => {
            const resp = contracts.assetManager.connect(nonAdmin).rebalance(deployerAddress, []);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
    });

    context("PureTokenAdapter", () => {
        before(beforeContext);
        it("setAssetManager cannot be called by non owner", async () => {
            const resp = contracts.adapters.pureToken.connect(nonAdmin).setAssetManager(deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setFloor cannot be called by non owner", async () => {
            const resp = contracts.adapters.pureToken.connect(nonAdmin).setFloor(deployerAddress, 0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("setCeiling cannot be called by non owner", async () => {
            const resp = contracts.adapters.pureToken.connect(nonAdmin).setCeiling(deployerAddress, 0);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
        it("claimRewards cannot be called by non owner", async () => {
            const resp = contracts.adapters.pureToken.connect(nonAdmin).claimRewards(deployerAddress, deployerAddress);
            await expect(resp).to.be.revertedWith(error.SenderNotAdmin);
        });
    });
});
