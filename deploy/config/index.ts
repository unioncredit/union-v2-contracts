import {ethers} from "ethers";
import {parseUnits} from "ethers/lib/utils";

import {DeployConfig} from "../index";
import {isForked} from "../../test/utils/fork";

// Config
import arbitrumConfig from "./arbitrum";
import goerliConfig from "./goerli";

// Fork Config
import goerliForkConfig from "./fork/goerli";

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

export const getConfig = (name?: string, forked: boolean = false) => {
    const configName = name || process.env.CONFIG;

    if (forked || isForked()) {
        switch (configName) {
            case "goerli":
                return {...baseConfig, ...goerliForkConfig};
            default:
                return baseConfig;
        }
    } else {
        switch (configName) {
            case "arbitrum":
                return {...baseConfig, ...arbitrumConfig};
            case "goerli":
                return {...baseConfig, ...goerliConfig};
            default:
                return baseConfig;
        }
    }
};
