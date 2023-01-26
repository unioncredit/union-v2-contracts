import {parseUnits} from "ethers/lib/utils";

import {DeployConfig} from "../index";

export default {
    userManager: {
        maxOverdue: "120", // 12 x overdueBlocks
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
        overdueBlocks: "10" // in blocks
    }
} as DeployConfig;
