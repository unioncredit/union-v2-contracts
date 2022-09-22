import * as fs from "fs";
import * as path from "path";

import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment, TaskArguments} from "hardhat/types";
import {ethers} from "ethers";
import deploy from "../deploy";

import {getConfig} from "../deploy/config";

task("report", "Generate protocol report").setAction(async (_: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    // ------------------------------------------------------
    // Setup
    // ------------------------------------------------------

    const callSigner = ethers.Wallet.createRandom().connect(hre.ethers.provider);

    const config = getConfig(hre.network.name, true);
    const contracts = await deploy(config, callSigner);

    const reportDate = new Date()
        .toUTCString()
        .replace(/[^0-9a-zA-Z: ]+/g, "")
        .replace(/ |:/g, "-")
        .toLowerCase();

    console.log("[*] Generating report for:", reportDate);

    const results = {} as any;

    // ------------------------------------------------------
    // UserManager
    // ------------------------------------------------------

    const userManager = {} as any;

    userManager.assetManager = await contracts.userManager.assetManager();
    userManager.unionToken = await contracts.userManager.unionToken();
    userManager.stakingToken = await contracts.userManager.stakingToken();
    userManager.comptroller = await contracts.userManager.comptroller();
    userManager.maxOverdueBlocks = await contracts.userManager.maxOverdueBlocks();
    userManager.effectiveCount = await contracts.userManager.effectiveCount();
    userManager.uToken = await contracts.userManager.uToken();
    userManager.newMemberFee = await contracts.userManager.newMemberFee();
    userManager.maxStakeAmount = await contracts.userManager.maxStakeAmount();
    userManager.totalStaked = await contracts.userManager.totalStaked();
    userManager.totalFrozen = await contracts.userManager.totalFrozen();
    userManager.maxVouchers = await contracts.userManager.maxVouchers();

    results.userManager = userManager;

    // ------------------------------------------------------
    // Generate HTML
    // ------------------------------------------------------

    const rows = Object.keys(results).map(group => {
        const rows = Object.keys(results[group]).map(rowKey => {
            return `<tr><td>${rowKey}</td><td>${results[group][rowKey].toString()}</td><tr>`;
        });
        return `<tr><td><strong>${group}</strong></td><td></td></tr>${rows.join("")}`;
    });

    const html = `<table><tbody>${rows.join("")}</tbody></table>`;

    const saveDir = path.resolve(__dirname, "..", "reports");
    if (!fs.existsSync(saveDir)) {
        console.log("[*] Reports directory does not exist.");
        console.log("[*] Creating reports directory");
        fs.mkdirSync(saveDir);
    }

    console.log("[*] Saving report");
    const savePath = path.resolve(saveDir, `${hre.network.name}--${reportDate}.html`);
    fs.writeFileSync(savePath, html);
    console.log("[*] Report saved to:", savePath);
});
