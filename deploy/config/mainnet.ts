import {DeployConfig} from "../index";

export default {
    addresses: {
        dai: "0x6b175474e89094c44da98b954eedeac495271d0f",
        aave: {
            market: "0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5",
            lendingPool: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
        },
        whales: {dai: "0x5d38b4e4783e34e2301a2a36c39a03c45798c4dd"}
    }
} as DeployConfig;
