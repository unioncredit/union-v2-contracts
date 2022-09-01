const fs = require("fs");
const path = require("path");
const glob = require("glob");
const {SolidityMetricsContainer} = require("solidity-code-metrics");

function getAllContracts() {
    return new Promise(res => {
        glob("contracts/**/*.sol", {}, function (_, files) {
            const filteredFiles = files.filter(
                file => !(file.startsWith("contracts/interfaces") || file.startsWith("contracts/mocks"))
            );
            res(filteredFiles);
        });
    });
}

const options = {
    basePath: "",
    inputFileGlobExclusions: undefined,
    inputFileGlob: undefined,
    inputFileGlobLimit: undefined,
    debug: false,
    repoInfo: {
        branch: undefined,
        commit: undefined,
        remote: undefined
    }
};

const metrics = new SolidityMetricsContainer("codeMetrics", options);

async function main() {
    const files = await getAllContracts();

    console.log("[*] Analyzing files");
    for (const file of files) {
        const fullPath = path.resolve(__dirname, "..", file);
        metrics.analyze(fullPath);
        console.log(`    - ${file}`);
    }

    const totals = metrics.totals();
    const sloc = totals.totals.sloc;

    console.log("");
    console.log(`[*] Source Lines of Code`);
    Object.keys(sloc).forEach(key => {
        console.log(`    - ${key}: ${sloc[key]}`);
    });

    console.log("");
}

main();
