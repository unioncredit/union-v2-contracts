import {DeployConfig} from "../optimism";
import {parseUSDC} from "../../utils";
import {parseUnits} from "ethers/lib/utils";

export default {
    userManager: {
        maxOverdue: "5184000", // in seconds, 60 day
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
        overdueTime: "2592000", // in seconds, 30 day
        mintFeeRate: parseUnits("0")
    },
    comptroller: {
        halfDecayPoint: "1"
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
        unionToken: "0x5Dfe42eEA70a3e6f93EE54eD9C321aF07A85535C", // mainnet address
        usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC on base
        aave: {
            market: "0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44",
            lendingPool: "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5"
        },
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xBBD3321f377742c4b3fe458b270c2F271d3294D8", // mainnet address
        opAdminAddress: "0x567e418D831969142b52228b65a88f894e2D79a8", //use l2 multi-sig address
        opUnion: "0x946A2C918F3D928B918C01D813644f27Bcd29D96",
        opOwner: "0x20473Af81162B3E79F0333A2d8D64C88a71B88e8",
        marketRegistry: "0x46A48D1e81F6002501251AD563a0e16655525E85",
        comptroller: "0x37C092D275E48e3c9001059D9B7d55802CbDbE04",
        assetManager: "0x393d7299c2caA940b777b014a094C3B2ea45ee2B"
    }
} as DeployConfig;
