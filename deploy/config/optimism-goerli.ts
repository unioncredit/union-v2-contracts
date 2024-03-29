import {parseUnits} from "ethers/lib/utils";
import {DeployConfig} from "../index";

export default {
    userManager: {
        maxOverdue: "86400", // in seconds, 1 day
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
        overdueTime: "86400", // in seconds, 1 day
        mintFeeRate: parseUnits("0")
    },
    addresses: {
        guardian: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4",
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        dai: "0xD9662ae38fB577a3F6843b6b8EB5af3410889f3A", // DAI used by aave on goerli-optimism
        aave: {
            market: "0x062BB55A42875366DB1B7D227B73621C33a6cB6b",
            lendingPool: "0xCAd01dAdb7E97ae45b89791D986470F3dfC256f7"
        },
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        timelock: "0xe614dAf5717cab0c2abC49a7Fa9AbEFD16b6ddF0", //use l1 timelock address
        opAdminAddress: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4" //use l2 multi-sig address
    }
} as DeployConfig;
