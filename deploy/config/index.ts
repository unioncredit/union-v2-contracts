import {ethers} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {DeployConfig} from "../index";

// Config
import arbitrumConfig from "./arbitrum";
import goerliConfig from "./goerli";

// Fork Configs
import goerliForkConfig from "./goerli-fork";

export const baseConfig = {
    addresses: {
        aave: {
            lendingPool: ethers.constants.AddressZero,
            market: ethers.constants.AddressZero
        }
    },
    userManager: {
        maxOverdue: "2367000", // 12 x overdueBlocks
        effectiveCount: "1",
        maxVouchers: "1000"
    },
    uToken: {
        name: "uDAI",
        symbol: "uDAI",
        initialExchangeRateMantissa: parseUnits("1"),
        reserveFactorMantissa: parseUnits("1"),
        originationFee: parseUnits("0.005"),
        debtCeiling: parseUnits("250000"),
        maxBorrow: parseUnits("25000"),
        minBorrow: parseUnits("100"),
        overdueBlocks: "197250"
    },
    fixedInterestRateModel: {
        interestRatePerBlock: "41668836919" // 10% APR, 41668836919 x 6575 (blocks per day) x 365,
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
        default:
            return baseConfig;
    }
};
