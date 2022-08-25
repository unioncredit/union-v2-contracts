import {parseUnits} from "ethers/lib/utils";
import arbitrumConfig from "./arbitrum";
import {AddressZero} from "../helpers";
import {DeployConfig} from "../index";

export const baseConfig = {
    addresses: {
        aave: {
            lendingPool: AddressZero,
            market: AddressZero
        }
    },
    userManager: {
        maxOverdue: "2367000", // 12 x overdueBlocks
        effectiveCount: "1"
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
    if (process.env.CONFIG === "arbitrum") {
        return {...baseConfig, ...arbitrumConfig};
    }

    return baseConfig;
};