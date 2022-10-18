import {DeployConfig} from "../index";

export default {
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        dai: "0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464", // DAI used by aave on goerli
        aave: {
            market: "0x0C501fB73808e1BD73cBDdd0c99237bbc481Bb58",
            lendingPool: "0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6"
        }
    }
} as DeployConfig;
