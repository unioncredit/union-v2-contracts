import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "solidity-coverage";

import "./tasks";

export default {
    networks: {
        hardhat: {
            accounts: {
                count: 13
            }
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.16",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    },
                    evmVersion: "istanbul"
                }
            }
        ]
    },
    paths: {cache: "hh-cache", tests: "./test/integration"},
    mocha: {timeout: 400000000000, require: ["./test/integration/helper.ts"]}
};
