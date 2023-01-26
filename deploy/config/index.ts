import {ethers} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {DeployConfig} from "../index";

// Config
import arbitrumConfig from "./arbitrum";
import goerliConfig from "./goerli";

// Fork Configs
import goerliForkConfig from "./goerli-fork";

// Local test configs
import localConfig from "./local";

// Optimism testnet configs
import optimismGoerliConfig from "./optimism-goerli";

export const baseConfig = {
    addresses: {
        aave: {
            lendingPool: ethers.constants.AddressZero,
            market: ethers.constants.AddressZero
        }
    },
    userManager: {
        maxOverdue: "2592000", // 12 x overdueBlocks
        effectiveCount: "1",
        maxVouchers: "400",
        maxVouchees: "1000"
    },
    uToken: {
        name: "uDAI",
        symbol: "uDAI",
        initialExchangeRateMantissa: parseUnits("1"),
        reserveFactorMantissa: parseUnits("1"),
        originationFee: parseUnits("0.005"),
        originationFeeMax: parseUnits("0.5"),
        debtCeiling: parseUnits("250000"),
        maxBorrow: parseUnits("25000"),
        minBorrow: parseUnits("100"),
        overdueBlocks: "216000" // in blocks, 30 days.
    },
    fixedInterestRateModel: {
        interestRatePerBlock: "38051750380" // 10% APR, 38051750380 x 7200 (blocks per day) x 365,
    },
    comptroller: {
        halfDecayPoint: "500000"
    }
} as DeployConfig;

export const getConfig = () => {
    switch (process.env.CONFIG) {
        case "arbitrum":
            return {...baseConfig, ...arbitrumConfig};
        case "goerli":
            return {...baseConfig, ...goerliConfig};
        case "goerli-fork":
            return {...baseConfig, ...goerliForkConfig};
        case "local":
            return {...baseConfig, ...localConfig};
        case "optimism-goerli":
            return {...baseConfig, ...optimismGoerliConfig};
        default:
            return baseConfig;
    }
};
