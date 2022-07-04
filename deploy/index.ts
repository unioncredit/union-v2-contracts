interface Addresses {
    userManager?: string;
    uToken?: string;
    fixedRateInterestModal?: string;
    comptroller?: string;
    assetManager?: string;
    adapters?: {
        pureTokenAdapter?: string;
    };
}

interface DeployConfig {
    addresses: Addresses;
}

interface Contracts {}

export default function (config: DeployConfig): Contracts {
    // deploy user manager
    // deploy uToken
    // -- deploy fixed interest rate modal
    // deploy comptroller
    // deploy asset manager
    // -- deploy pure token
    return {};
}
