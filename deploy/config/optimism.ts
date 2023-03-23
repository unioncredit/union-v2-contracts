import {parseUnits} from "ethers/lib/utils";
import {DeployConfig} from "../index";

export default {
    userManager: {
        maxOverdue: "2592000", // in blocks, 60 days
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
        overdueBlocks: "1296000", // in blocks, 30 days
        mintFeeRate: parseUnits("0")
    },
    fixedInterestRateModel: {
        interestRatePerBlock: "6341958397" // 10% APR, 38051750380 x 43200 (blocks per day) x 365,
    },
    addresses: {
        unionToken: "0x5Dfe42eEA70a3e6f93EE54eD9C321aF07A85535C",
        dai: "0x6b175474e89094c44da98b954eedeac495271d0f",
        aave: {
            market: "0x929EC64c34a17401F460460D4B9390518E5B473e",
            lendingPool: "0x794a61358d6845594f94dc1db02a252b5b4814ad"
        },
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xBBD3321f377742c4b3fe458b270c2F271d3294D8", // L1 timelock address
        opAdminAddress: "" // use l2 multi-sig address
    }
} as DeployConfig;
