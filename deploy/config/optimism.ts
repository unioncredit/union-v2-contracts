import {parseUnits} from "ethers/lib/utils";
import {DeployConfig} from "../index";

export default {
    uToken: {
        name: "uDAI",
        symbol: "uDAI",
        initialExchangeRateMantissa: parseUnits("1"),
        reserveFactorMantissa: parseUnits("1"),
        originationFee: parseUnits("0.005"),
        originationFeeMax: parseUnits("0.5"),
        debtCeiling: parseUnits("250000"),
        maxBorrow: parseUnits("25000"),
        minBorrow: parseUnits("1"),
        overdueTime: "2592000", // in seconds, 30 days.
        mintFeeRate: parseUnits("0")
    },
    comptroller: {
        halfDecayPoint: "1000"
    },
    pureAdapter: {
        floor: parseUnits("1000"),
        ceiling: parseUnits("1000000000")
    },
    aaveAdapter: {
        floor: parseUnits("1000"),
        ceiling: parseUnits("100000")
    },
    addresses: {
        guardian: "0xF7dc916eC6ee854b3a32f5D8DcF2ED0582e05Dc3",
        unionToken: "0x5Dfe42eEA70a3e6f93EE54eD9C321aF07A85535C",
        dai: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
        aave: {
            market: "0x929EC64c34a17401F460460D4B9390518E5B473e",
            lendingPool: "0x794a61358d6845594f94dc1db02a252b5b4814ad"
        },
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xBBD3321f377742c4b3fe458b270c2F271d3294D8", // L1 timelock address
        opAdminAddress: "0x652AbFA76d8Adf89560f110322FC63156C5aE5c8" // use l2 multi-sig address
    }
} as DeployConfig;
