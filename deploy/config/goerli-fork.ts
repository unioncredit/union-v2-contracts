import {DeployConfig} from "../index";

export default {
    admin: "0x23BBC53E1904b589d685e811c5D3410146f0Ab02", // deployer EOA
    addresses: {
        userManager: "0xB2499C1D140cBFD499a4d29Da7d61d9a70462842",
        uToken: "0x68d089D45035a2da0d1F60a47B21Dd2e9C26F8fe",
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        marketRegistry: "0x1317467564ce1eEaFD1760eF2d80DC7E71fb9c55",
        fixedRateInterestModel: "0xAe930fb9EcE01458C49e35b30091f1456b1A2ee4",
        comptroller: "0x5A571c18AB1B21797be988D38d3e08402c03a984",
        assetManager: "0x0Fb3B58Dc75647A4c5224B0e1eC3f710110fDC45",
        dai: "0xdc31ee1784292379fbb2964b3b9c4124d8f89c60",
        adapters: {
            pureTokenAdapter: "0xd0bd1e60Bc3b64fE07e76A12424b22b8b51dBB2D",
            aaveV3Adapter: "0x0000000000000000000000000000000000000000"
        },
        whales: {
            dai: "0x00ba938cc0df182c25108d7bf2ee3d37bce07513",
            union: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4"
        }
    }
} as DeployConfig;
