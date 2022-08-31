const fs = require("fs");
const path = require("path");
const glob = require("glob");

const regex = /(?<func>function [A-Za-z]+\([A-Za-z ]+\)([a-z ]+)(pure|view)([a-z ]+))/g;
const funcRegex = /function [a-zA-Z]+\([a-zA-Z ]+\)/;

function getAllContracts() {
    return new Promise(res => {
        glob("contracts/**/*.sol", {}, function (er, files) {
            const filteredFiles = files.filter(
                file => !(file.startsWith("contracts/interfaces") || file.startsWith("contracts/mocks"))
            );
            res(filteredFiles);
        });
    });
}

// macosx copy to paste board
function pbcopy(data) {
    var proc = require("child_process").spawn("pbcopy");
    proc.stdin.write(data);
    proc.stdin.end();
}

async function main() {
    const results = [];

    const files = await getAllContracts();

    for (const file of files) {
        const fullPath = path.resolve(__dirname, "..", file);
        const content = fs.readFileSync(fullPath, "utf8");
        const oneLine = content.replace(/\n/g, "");
        const matches = oneLine.match(regex);

        if (!matches || matches.length <= 0) {
            console.log(`[!] File: ${file}`);
            console.log("[!] No view functions found");
            console.log("");
            continue;
        }

        console.log(`[*] File: ${file}`);
        console.log(`    - View functions found: ${matches.length}`);
        for (const func of matches) {
            const f0 = func.match(funcRegex)[0];
            const f1 = f0.replace("function", "");
            console.log(`    + ${f1}`);

            // save to results array
            results.push({file, function: f1});
        }
        console.log("");
    }

    console.log(JSON.stringify(results));
    pbcopy(JSON.stringify(results));
}

main();
