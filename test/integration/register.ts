import "./testSetup";

import {expect} from "chai";
import {ethers} from "hardhat";
import {BigNumberish, Signer} from "ethers";
import {signERC2612Permit} from "eth-permit";

import error from "../utils/error";
import {isForked} from "../utils/fork";
import {getConfig} from "../../deploy/config";
import deploy, {Contracts} from "../../deploy";
import {getDeployer, getSigners, getUnion, fork} from "../utils";

describe("Register member", () => {
    let deployer: Signer;
    let deployerAddress: string;
    let contracts: Contracts;
    let signers: Signer[];
    let memberFee: BigNumberish;
    let member: Signer;
    let memberAddress: string;

    const beforeContext = async () => {
        if (isForked()) await fork();

        deployer = await getDeployer();
        deployerAddress = await deployer.getAddress();

        signers = await getSigners();

        contracts = await deploy({...getConfig(), admin: deployerAddress}, deployer);

        memberFee = await contracts.userManager.newMemberFee();
        await contracts.userManager.setEffectiveCount(0);

        member = signers[1];
        memberAddress = await member.getAddress();
        await getUnion(contracts.unionToken, memberAddress, memberFee);
    };

    beforeEach(beforeContext);

    it("register as a member", async () => {
        const balBefore = await contracts.unionToken.balanceOf(memberAddress);
        await contracts.unionToken.connect(member).approve(contracts.userManager.address, memberFee);
        await contracts.userManager.connect(member).registerMember(memberAddress);
        expect(await contracts.userManager.checkIsMember(memberAddress)).eq(true);
        const balAfter = await contracts.unionToken.balanceOf(memberAddress);
        expect(balBefore.sub(balAfter)).eq(memberFee);
    });

    it("register as a member with a permit", async () => {
        const balBefore = await contracts.unionToken.balanceOf(memberAddress);
        const result = await signERC2612Permit(
            ethers.provider,
            {
                name: "Union Token",
                chainId: 31337,
                version: "1",
                verifyingContract: contracts.unionToken.address
            },
            memberAddress,
            contracts.userManager.address,
            memberFee.toString()
        );

        await contracts.userManager
            .connect(member)
            .registerMemberWithPermit(memberAddress, memberFee, result.deadline, result.v, result.r, result.s);
        expect(await contracts.userManager.checkIsMember(memberAddress)).eq(true);
        const balAfter = await contracts.unionToken.balanceOf(memberAddress);
        expect(balBefore.sub(balAfter)).eq(memberFee);
    });

    it("cannot register without vouches", async () => {
        await contracts.userManager.setEffectiveCount(1);
        await contracts.unionToken.connect(member).approve(contracts.userManager.address, memberFee);
        const tx = contracts.userManager.connect(member).registerMember(memberAddress);
        expect(tx).to.be.revertedWith(error.NotEnoughStakers);
    });
});
