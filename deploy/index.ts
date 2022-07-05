import {Signer} from "ethers";

import {
    AssetManager__factory,
    Comptroller,
    Comptroller__factory,
    UserManager,
    UserManager__factory,
    UToken,
    UToken__factory,
    AssetManager,
    PureTokenAdapter,
    PureTokenAdapter__factory,
    ERC20,
    ERC20__factory,
    FaucetERC20,
    FaucetERC20__factory,
    IUnionToken,
    IUnionToken__factory,
    FaucetERC20_ERC20Permit,
    FaucetERC20_ERC20Permit__factory,
    MarketRegistry,
    MarketRegistry__factory
} from "../typechain-types";
import {deployProxy, deployContract} from "./helpers";

interface Addresses {
    userManager?: string;
    uToken?: string;
    unionToken?: string;
    dai?: string;
    marketRegistry?: string;
    fixedRateInterestModal?: string;
    comptroller?: string;
    assetManager?: string;
    adapters?: {
        pureTokenAdapter?: string;
    };
}

interface DeployConfig {
    admin: string;
    addresses: Addresses;
    userManager: {
        maxOverdue: number;
        effectiveCount: number;
    };
    uToken: {
        name: string;
        symbol: string;
        initialExchangeRateMantissa: number;
        reserveFactorMantissa: number;
        originationFee: number;
        debtCeiling: number;
        maxBorrow: number;
        minBorrow: number;
        overdueBlocks: number;
    };
}

interface Contracts {
    userManager: UserManager;
    uToken: UToken;
    fixedInterestRateModel: null;
    comptroller: Comptroller;
    assetManager: AssetManager;
    dai: ERC20 | FaucetERC20;
    unionToken: IUnionToken | FaucetERC20_ERC20Permit;
    adapters: {
        pureToken: PureTokenAdapter;
    };
}

export default async function (config: DeployConfig, signer: Signer): Promise<Contracts> {
    // deploy market registry
    let marketRegistry: MarketRegistry;
    if (config.addresses.marketRegistry) {
        marketRegistry = MarketRegistry__factory.connect(config.addresses.marketRegistry, signer);
    } else {
        const {proxy} = await deployProxy<MarketRegistry>(
            signer,
            new MarketRegistry__factory(signer),
            "MarketRegistry",
            {
                signature: "__MarketRegistry_init()",
                args: []
            }
        );
        marketRegistry = proxy;
    }

    // deploy UNION
    let unionToken: IUnionToken | FaucetERC20_ERC20Permit;
    if (config.addresses.unionToken) {
        unionToken = IUnionToken__factory.connect(config.addresses.unionToken, signer);
    } else {
        unionToken = await deployContract<FaucetERC20_ERC20Permit>(
            new FaucetERC20_ERC20Permit__factory(signer),
            "UnionToken",
            ["Union Token", "UNION"]
        );
    }

    // deploy DAI
    let dai: ERC20 | FaucetERC20;
    if (config.addresses.dai) {
        dai = ERC20__factory.connect(config.addresses.dai, signer);
    } else {
        dai = await deployContract<FaucetERC20>(new FaucetERC20__factory(signer), "DAI", ["DAI", "DAI"]);
    }

    // deploy comptroller
    let comptroller: Comptroller;
    if (config.addresses.comptroller) {
        comptroller = Comptroller__factory.connect(config.addresses.comptroller, signer);
    } else {
        const {proxy} = await deployProxy<Comptroller>(signer, new Comptroller__factory(signer), "Comtroller", {
            signature: "__Comptroller_init(address, address)",
            args: [unionToken.address, marketRegistry.address]
        });
        comptroller = proxy;
    }

    // deploy asset manager
    let assetManager: AssetManager;
    if (config.addresses.assetManager) {
        assetManager = AssetManager__factory.connect(config.addresses.assetManager, signer);
    } else {
        const {proxy} = await deployProxy<AssetManager>(signer, new AssetManager__factory(signer), "AssetManager", {
            signature: "__AssetManager_init(address)",
            args: [marketRegistry.address]
        });
        assetManager = proxy;
    }

    // deploy pure token
    let pureToken: PureTokenAdapter;
    if (config.addresses.adapters?.pureTokenAdapter) {
        pureToken = PureTokenAdapter__factory.connect(config.addresses.adapters?.pureTokenAdapter, signer);
    } else {
        const {proxy} = await deployProxy<PureTokenAdapter>(
            signer,
            new PureTokenAdapter__factory(signer),
            "PureTokenAdapter",
            {
                signature: "__PureTokenAdapter_init(address)",
                args: [assetManager.address]
            }
        );
        pureToken = proxy;
    }

    // deploy user manager
    let userManager: UserManager;
    if (config.addresses.userManager) {
        userManager = UserManager__factory.connect(config.addresses.userManager, signer);
    } else {
        const {proxy} = await deployProxy<UserManager>(signer, new UserManager__factory(signer), "UserManager", {
            signature: "__UserManager_init(address,address,address,address,address,uint256,uint256)",
            args: [
                assetManager.address,
                unionToken.address,
                dai.address,
                comptroller.address,
                config.admin,
                config.userManager.maxOverdue,
                config.userManager.effectiveCount
            ]
        });
        userManager = proxy;
    }

    // deploy uToken
    let uToken: UToken;
    if (config.addresses.uToken) {
        uToken = UToken__factory.connect(config.addresses.uToken, signer);
    } else {
        const {proxy} = await deployProxy<UToken>(signer, new UToken__factory(signer), "UToken", {
            signature:
                "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
            args: [
                config.uToken.name,
                config.uToken.symbol,
                dai.address,
                config.uToken.initialExchangeRateMantissa,
                config.uToken.reserveFactorMantissa,
                config.uToken.originationFee,
                config.uToken.debtCeiling,
                config.uToken.maxBorrow,
                config.uToken.minBorrow,
                config.uToken.overdueBlocks,
                config.admin
            ]
        });
        uToken = proxy;
    }

    // TODO: deploy fixed interest rate model

    return {
        userManager,
        uToken,
        unionToken,
        fixedInterestRateModel: null,
        comptroller,
        assetManager,
        dai,
        adapters: {pureToken}
    };
}
