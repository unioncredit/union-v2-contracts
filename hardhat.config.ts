import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "solidity-coverage";

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
                version: "0.8.11",
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
    paths: {cache: "hh-cache", tests: "./test/"},
    mocha: {timeout: 400000000000}
};