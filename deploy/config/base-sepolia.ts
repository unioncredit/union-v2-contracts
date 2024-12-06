import {DeployConfig} from "../optimism";
import {parseUSDC} from "../../utils";
import {parseUnits} from "ethers/lib/utils";

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
        initialExchangeRateMantissa: parseUnits("1"),
        reserveFactorMantissa: parseUnits("1"),
        originationFee: parseUnits("0.005"),
        originationFeeMax: parseUnits("0.5"),
        debtCeiling: parseUSDC("250000"),
        maxBorrow: parseUSDC("25000"),
        minBorrow: parseUSDC("100"),
        overdueTime: "86400", // in seconds, 1 day
        mintFeeRate: parseUnits("0")
    },
    comptroller: {
        halfDecayPoint: "1000"
    },
    pureAdapter: {
        floor: parseUSDC("1000"),
        ceiling: parseUSDC("100000")
    },
    aaveAdapter: {
        floor: parseUSDC("1000"),
        ceiling: parseUSDC("100000")
    },
    addresses: {
        guardian: "0xCbD1c32A1b3961cC43868B8bae431Ab0dA65beEb",
        unionToken: "0xE4ADdfdf5641EB4e15F60a81F63CEd4884B49823", // sepolia address
        usdc: "0x036CbD53842c5426634e7929541eC2318f3dCF7e", // USDC on base-sepolia
        aave: {
            market: "0x659FbB419151b8e752C4589DffcA3403865B7232",
            lendingPool: "0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b"
        },
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xdA2C8b9f14e1F20a637A7B9f86d4aa78DFbDB3cF", // sepolia address
        opAdminAddress: "0xCbD1c32A1b3961cC43868B8bae431Ab0dA65beEb" //use l2 multi-sig address
    }
} as DeployConfig;
