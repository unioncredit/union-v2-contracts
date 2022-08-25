import {formatUnits} from "ethers/lib/utils";
import {fork, getDeployer} from "../utils";

before(async () => {
    const deployer = await getDeployer();
    const deployerAddress = await deployer.getAddress();
    const deployerBalance = await deployer.getBalance();
    console.log("[*] Deployer:", deployerAddress);
    console.log("    BALANCE:", formatUnits(deployerBalance));

    if (process.env.FORK_NODE_URL) {
        if (!process.env.FORK_BLOCK) {
            console.log("[!] FORK_BLOCK not set");
            console.log("");
            process.exit();
        }

        console.log("[*] Running test in fork mode");
        console.log(`    FORK_BLOCK:    ${process.env.FORK_BLOCK}`);
        console.log(`    FORK_NODE_URL: ${process.env.FORK_NODE_URL}`);
        console.log("");

        await fork();
    }
});
