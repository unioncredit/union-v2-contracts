import {formatUnits} from "ethers/lib/utils";
import {fork, getDeployer} from "../utils";
import {use, AssertionError} from "chai";

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

use((chai, _) => {
    chai.Assertion.addMethod("revertedWith", function (this: any, expectedErrorSig: unknown) {
        const onSuccess = () => {
            this.assert(
                false,
                `Expected transaction to be reverted with reason '${expectedErrorSig}', but it didn't revert`
            );
        };

        const onError = (error: any) => {
            if (!(error instanceof Error)) {
                throw new AssertionError("Expected an Error object");
            }

            error = error as any;

            const errorData = error.data ?? error.error?.data;
            if (errorData === undefined) throw error;
            const returnData = typeof errorData === "string" ? errorData : errorData.data;
            if (returnData === undefined || typeof returnData !== "string") throw error;
            const errorSig = returnData.slice(0, 10);

            this.assert(
                errorSig === expectedErrorSig,
                `Expected to revert with sig: ${expectedErrorSig} but found: ${errorSig}`
            );
        };

        const derivedPromise = Promise.resolve(this._obj).then(onSuccess, onError);

        this.then = derivedPromise.then.bind(derivedPromise);
        this.catch = derivedPromise.catch.bind(derivedPromise);

        return this;
    });
});
