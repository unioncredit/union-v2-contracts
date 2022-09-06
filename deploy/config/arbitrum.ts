import {DeployConfig} from "../index";

export default {
    addresses: {
        dai: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
        aave: {
            market: "0x929ec64c34a17401f460460d4b9390518e5b473e",
            lendingPool: "0x794a61358d6845594f94dc1db02a252b5b4814ad"
        },
        whales: {
            dai: "0xc5ed2333f8a2c351fca35e5ebadb2a82f5d254c3"
        }
    }
} as DeployConfig;
