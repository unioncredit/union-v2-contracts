import {DeployConfig} from "../index";

export default {
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        opOwnerAddress: "0xe614dAf5717cab0c2abC49a7Fa9AbEFD16b6ddF0", //use l1 timelock address
        opAdminAddress: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4" //use l2 multi-sig address
    }
} as DeployConfig;
