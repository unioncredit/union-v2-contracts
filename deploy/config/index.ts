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

// Optimism configs
import optimismConfig from "./optimism";

// Mainnet configs
import mainnetConfig from "./mainnet";

// Base Sepolia configs
import baseSepoliaConfig from "./base-sepolia";

export const baseConfig = {
    addresses: {
        aave: {
            lendingPool: ethers.constants.AddressZero,
            market: ethers.constants.AddressZero
        }
    },
    userManager: {
        maxOverdue: "5184000", // in seconds, 60 days
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
        overdueTime: "2592000", // in seconds, 30 days.
        mintFeeRate: parseUnits("0.001")
    },
    fixedInterestRateModel: {
        interestRatePerSecond: "3170979198" // 10% APR, 3170979198 x 86400 (seconds per day) x 365,
    },
    comptroller: {
        halfDecayPoint: "500000"
    }
} as DeployConfig;

export const getConfig = (network: string) => {
    switch (network) {
        case "arbitrum":
            return {...baseConfig, ...arbitrumConfig};
        case "goerli":
            return {...baseConfig, ...goerliConfig};
        case "goerli-fork":
            return {...baseConfig, ...goerliForkConfig};
        case "hardhat":
            return {...baseConfig, ...localConfig};
        case "optimism-goerli":
            return {...baseConfig, ...optimismGoerliConfig};
        case "optimism":
            return {...baseConfig, ...optimismConfig};
        case "mainnet":
            return {...baseConfig, ...mainnetConfig};
        case "base-sepolia":
            return {...baseConfig, ...baseSepoliaConfig};
        default:
            return baseConfig;
    }
};
