import {DeployConfig} from "../index";

export default {
    admin: "0x23BBC53E1904b589d685e811c5D3410146f0Ab02", // deployer EOA
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        dai: "0x73967c6a0904aA032C103b4104747E88c566B1A2",
        userManager: "0x4A6aeBbfFFa78D9b3434d604B7c85f3C57aaE1C4",
        uToken: "0x79f3AD63E9016eD7b0FB7153509C4CaCba4812D9",
        marketRegistry: "0xC47d41874b9b4434da9D39eF5AD6820D6C32375b",
        fixedRateInterestModel: "0x628F018Dc633557a4B2e27325041a58CD49c47A8",
        comptroller: "0x6AB0c9c0C8f1a0C34c90e18d381b1d61910Fa742",
        assetManager: "0x0683d30F7bCc69143023136329F55D14E434D436",
        adapters: {
            pureTokenAdapter: "0x82f2A4a424ad41C1b2b7B31DA899377e4937f898",
            aaveV3Adapter: "0x0000000000000000000000000000000000000000"
        },
        whales: {
            dai: "0x00ba938cc0df182c25108d7bf2ee3d37bce07513",
            union: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4"
        }
    }
} as DeployConfig;
