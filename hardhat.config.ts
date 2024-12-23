// import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "solidity-coverage";
import "@nomicfoundation/hardhat-chai-matchers";
// import "@nomicfoundation/hardhat-verify";

console.log("[*] Environment");
console.log(`    - ETHERSCAN_API_KEY: ${process.env.BASE_SEPOLIA_API_KEY}`);
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
            url: process.env.NODE_URL || "https://goerli.optimism.io"
        },
        optimism: {
            url: process.env.NODE_URL || "https://optimism-mainnet.infura.io"
        },
        mainnet: {
            url: process.env.NODE_URL || "https://mainnet.infura.io/v3/"
        },
        sepolia: {
            url: process.env.NODE_URL || "https://eth-sepolia.public.blastapi.io"
        },
        "base-sepolia": {
            url: process.env.NODE_URL || "https://sepolia.base.org"
        },
        "base-mainnet": {
            url: process.env.NODE_URL || "https://mainnet.base.org"
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
        apiKey: {
            mainnet: process.env.ETHERSCAN_API_KEY,
            sepolia: process.env.SEPOLIA_API_KEY,
            "base-sepolia": process.env.BASE_SEPOLIA_API_KEY,
            optimisticEthereum: process.env.ETHERSCAN_API_KEY,
            "base-mainnet": process.env.BASE_MAINNET_API_KEY,
            base: process.env.BASE_MAINNET_API_KEY
        },
        customChains: [
            {
                network: "base-sepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org"
                }
            }
        ]
    },
    sourcify: {
        enabled: false
    }
};
