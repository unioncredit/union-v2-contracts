import {DeployConfig} from "../index";

export default {
    addresses: {
        unionToken: "0x23B0483E07196c425d771240E81A9c2f1E113D3A",
        opUnion: "0x04622FDe6a7C0B19Ff7748eC8882870367530074",
        opL2Bridge: "0x4200000000000000000000000000000000000010",
        opL2CrossDomainMessenger: "0x4200000000000000000000000000000000000007",
        opOwner: "0xe614dAf5717cab0c2abC49a7Fa9AbEFD16b6ddF0", //use l1 timelock address
        opAdmin: "0x7a0C61EdD8b5c0c5C1437AEb571d7DDbF8022Be4" //use l2 multi-sig address
    },
    admin: "0x5eFD403912661A984B810814Ba366Aa633777353" //use l2 OpOwner address
    }
} as DeployConfig;
