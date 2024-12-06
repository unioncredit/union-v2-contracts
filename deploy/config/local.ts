import {DeployConfig} from "../optimism";
import {parseUSDC} from "../../utils";

export default {
    userManager: {
        maxOverdue: "86400", // in seconds, 1 day
        effectiveCount: "0",
        maxVouchers: "400",
        maxVouchees: "1000"
    },
    uToken: {
        name: "uUSDC",
        symbol: "uUSDC",
        initialExchangeRateMantissa: parseUSDC("1"),
        reserveFactorMantissa: parseUSDC("1"),
        originationFee: parseUSDC("0.005"),
        originationFeeMax: parseUSDC("0.5"),
        debtCeiling: parseUSDC("250000"),
        maxBorrow: parseUSDC("25000"),
        minBorrow: parseUSDC("100"),
        overdueTime: "86400", // in seconds, 1 day
        mintFeeRate: parseUSDC("0")
    },
    comptroller: {
        halfDecayPoint: "1000"
    },
    pureAdapter: {
        floor: parseUSDC("1000"),
        ceiling: parseUSDC("100000")
    },
    addresses: {
        guardian: "0xCbD1c32A1b3961cC43868B8bae431Ab0dA65beEb",
        unionToken: "0xE4ADdfdf5641EB4e15F60a81F63CEd4884B49823", // sepolia address
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xdA2C8b9f14e1F20a637A7B9f86d4aa78DFbDB3cF", // sepolia address
        opAdminAddress: "0xCbD1c32A1b3961cC43868B8bae431Ab0dA65beEb" //use l2 multi-sig address
    }
} as DeployConfig;
