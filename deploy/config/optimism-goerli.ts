import {DeployConfig} from "../index";

export default {
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        opOwner: "", //use l1 timelock address
        opAdmin: "" //use l2 multi-sig address
    },
    admin: "" //use l2 OpOwner address
} as DeployConfig;
