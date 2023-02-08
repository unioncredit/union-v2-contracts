// import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "solidity-coverage";
import "@nomicfoundation/hardhat-chai-matchers";

console.log("[*] Environment");
console.log(`    - ETHERSCAN_API_KEY: ${process.env.ETHERSCAN_API_KEY}`);
console.log(`    - NODE_URL: ${process.env.NODE_URL}`);

export default {
    networks: {
        hardhat: {
            accounts: {
                count: 13
            }
        },
        goerli: {
            url: process.env.NODE_URL || ""
        },
        "optimism-goerli": {
            url: process.env.NODE_URL || ""
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.16",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    },
                    evmVersion: "istanbul"
                }
            }
        ]
    },
    paths: {cache: "hh-cache", tests: "./test/integration"},
    mocha: {timeout: 400000000000, require: ["./test/integration/helper.ts"]},
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    }
};
