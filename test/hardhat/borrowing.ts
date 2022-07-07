import {expect} from "chai";
import {Signer} from "ethers";
import {ethers} from "hardhat";

import deploy, {Contracts} from "../../deploy";
import config from "../../deploy/config";

describe("Borrowing and repaying", () => {
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

    context("Member borrows from credit line", () => {
        before(beforeContext);
        it("cannot borrow with no available credit");
        it("cannot borrow with no DAI in reserves");
        it("locks stakers (in \"first in\" order)");
        it("cannot borrow if overdue");
    });

    context("Borrowing interest/accounting", () => {
        before(beforeContext);
        it("moves fee to reserves");
        it("increases total borrows");
        it("changes uToken rate");
        it("Interest is accrued but not backed");
    });

    context("Member repays debt", () => {
        before(beforeContext);
        it("cannot repay 0");
        it("repaying less than interest doesn't update last repaid");
        it("unlocks stakers (in \"first in first out\" order)");
    });
    
    context("Repay interest/accounting", () => {
        before(beforeContext);
        it("reduces total borrows");
        it("changes uToken rate");
    });
});
