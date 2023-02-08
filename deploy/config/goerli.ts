import {DeployConfig} from "../index";

export default {
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        dai: "0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464", // DAI used by aave on goerli
        aave: {
            market: "0x0C501fB73808e1BD73cBDdd0c99237bbc481Bb58",
            lendingPool: "0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6"
        },
        opL1Bridge: "0x636Af16bf2f682dD3109e60102b8E1A089FedAa8",
        opUnion: "0xe8281FdF8945E06C608b1C95D8f6dCEDbf2AC323"
    }
} as DeployConfig;
