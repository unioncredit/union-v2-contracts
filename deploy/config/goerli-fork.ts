import {DeployConfig} from "../index";

export default {
    admin: "0x23BBC53E1904b589d685e811c5D3410146f0Ab02", // deployer EOA
    addresses: {
        userManager: "0x250dbBf86B61A967Be8cF12f180252bD79af52F3",
        uToken: "0x95bBE7c4Bb22d324DBf333627Caf2F93983295a8",
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        marketRegistry: "0x9d514609bf3eb19E04F05e7429fc8084498bE6Fb",
        fixedRateInterestModel: "0xbebdbe467Bb5b1dD8486771edC35040771a5939f",
        comptroller: "0xE29229a88f6Bb6CfD3aec5C4722aEa8A799Be32d",
        assetManager: "0xd55021755710A79fAaC76Ca0c72b0dEF95C53b03",
        dai: "0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464",
        adapters: {
            pureTokenAdapter: "0xA07025e29e461f8d4FB4c93eEF3CB9A6BCD00B17",
            aaveV3Adapter: "0xcde0CCfd9242e592F6ce92E8499D3a4F283Cb885"
        },
        whales: {
            dai: "0x00ba938cc0df182c25108d7bf2ee3d37bce07513",
            union: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4"
        }
    }
} as DeployConfig;
