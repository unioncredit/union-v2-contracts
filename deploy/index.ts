import {BigNumberish, Signer} from "ethers";

import {
    AssetManager__factory,
    Comptroller,
    Comptroller__factory,
    UserManagerERC20,
    UserManagerERC20__factory,
    UToken,
    UToken__factory,
    AssetManager,
    PureTokenAdapter,
    PureTokenAdapter__factory,
    IUnionToken,
    IUnionToken__factory,
    FaucetERC20_ERC20Permit,
    FaucetERC20_ERC20Permit__factory,
    MarketRegistry,
    MarketRegistry__factory,
    FixedInterestRateModel,
    FixedInterestRateModel__factory,
    AaveV3Adapter,
    AaveV3Adapter__factory,
    IDai__factory,
    IDai
} from "../typechain-types";
import {deployProxy, deployContract} from "./helpers";

export interface Addresses {
    userManager?: string;
    uToken?: string;
    unionToken?: string;
    dai?: string;
    marketRegistry?: string;
    fixedRateInterestModel?: string;
    comptroller?: string;
    assetManager?: string;
    adapters?: {
        aaveV3Adapter?: string;
        pureTokenAdapter?: string;
    };
    aave?: {
        lendingPool?: string;
        market?: string;
    };
    whales?: {
        dai?: string;
        union?: string;
    };
}

export interface DeployConfig {
    admin: string;
    addresses: Addresses;
    userManager: {
        maxOverdue: BigNumberish;
        effectiveCount: BigNumberish;
        maxVouchers: BigNumberish;
    };
    uToken: {
        name: string;
        symbol: string;
        initialExchangeRateMantissa: BigNumberish;
        reserveFactorMantissa: BigNumberish;
        originationFee: BigNumberish;
        debtCeiling: BigNumberish;
        maxBorrow: BigNumberish;
        minBorrow: BigNumberish;
        overdueBlocks: BigNumberish;
    };
    fixedInterestRateModel: {
        interestRatePerBlock: BigNumberish;
    };
    comptroller: {
        halfDecayPoint: BigNumberish;
    };
}

export interface Contracts {
    userManager: UserManagerERC20;
    uToken: UToken;
    fixedInterestRateModel: FixedInterestRateModel;
    comptroller: Comptroller;
    assetManager: AssetManager;
    dai: IDai | FaucetERC20_ERC20Permit;
    marketRegistry: MarketRegistry;
    unionToken: IUnionToken | FaucetERC20_ERC20Permit;
    adapters: {
        pureToken: PureTokenAdapter;
        aaveV3Adapter?: AaveV3Adapter;
    };
}

export default async function (
    config: DeployConfig,
    signer: Signer,
    debug = false,
    waitForBlocks: number | undefined = undefined
): Promise<Contracts> {
    // deploy market registry
    let marketRegistry: MarketRegistry;
    if (config.addresses.marketRegistry) {
        marketRegistry = MarketRegistry__factory.connect(config.addresses.marketRegistry, signer);
    } else {
        const {proxy} = await deployProxy<MarketRegistry>(
            new MarketRegistry__factory(signer),
            "MarketRegistry",
            {
                signature: "__MarketRegistry_init()",
                args: []
            },
            debug
        );
        marketRegistry = MarketRegistry__factory.connect(proxy.address, signer);
    }

    // deploy UNION
    let unionToken: IUnionToken | FaucetERC20_ERC20Permit;
    if (config.addresses.unionToken) {
        unionToken = IUnionToken__factory.connect(config.addresses.unionToken, signer);
    } else {
        unionToken = await deployContract<FaucetERC20_ERC20Permit>(
            new FaucetERC20_ERC20Permit__factory(signer),
            "UnionToken",
            ["Union Token", "UNION"],
            debug,
            waitForBlocks
        );
    }

    // deploy DAI
    let dai: IDai | FaucetERC20_ERC20Permit;
    if (config.addresses.dai) {
        dai = IDai__factory.connect(config.addresses.dai, signer);
    } else {
        dai = await deployContract<FaucetERC20_ERC20Permit>(
            new FaucetERC20_ERC20Permit__factory(signer),
            "DAI",
            ["DAI", "DAI"],
            debug,
            waitForBlocks
        );
    }

    // deploy comptroller
    let comptroller: Comptroller;
    if (config.addresses.comptroller) {
        comptroller = Comptroller__factory.connect(config.addresses.comptroller, signer);
    } else {
        const {proxy} = await deployProxy<Comptroller>(new Comptroller__factory(signer), "Comptroller", {
            signature: "__Comptroller_init(address,address,uint256)",
            args: [unionToken.address, marketRegistry.address, config.comptroller.halfDecayPoint]
        });
        comptroller = Comptroller__factory.connect(proxy.address, signer);
    }

    // deploy asset manager
    let assetManager: AssetManager;
    if (config.addresses.assetManager) {
        assetManager = AssetManager__factory.connect(config.addresses.assetManager, signer);
    } else {
        const {proxy} = await deployProxy<AssetManager>(
            new AssetManager__factory(signer),
            "AssetManager",
            {
                signature: "__AssetManager_init(address)",
                args: [marketRegistry.address]
            },
            debug
        );
        assetManager = AssetManager__factory.connect(proxy.address, signer);
    }

    // deploy user manager
    let userManager: UserManagerERC20;
    if (config.addresses.userManager) {
        userManager = UserManagerERC20__factory.connect(config.addresses.userManager, signer);
    } else {
        const {proxy} = await deployProxy<UserManagerERC20>(
            new UserManagerERC20__factory(signer),
            "UserManagerERC20",
            {
                signature: "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256)",
                args: [
                    assetManager.address,
                    unionToken.address,
                    dai.address,
                    comptroller.address,
                    config.admin,
                    config.userManager.maxOverdue,
                    config.userManager.effectiveCount,
                    config.userManager.maxVouchers
                ]
            },
            debug
        );
        userManager = UserManagerERC20__factory.connect(proxy.address, signer);
        await marketRegistry.setUserManager(dai.address, userManager.address);
    }

    // deploy fixedInterestRateModel
    let fixedInterestRateModel: FixedInterestRateModel;
    if (config.addresses.fixedRateInterestModel) {
        fixedInterestRateModel = FixedInterestRateModel__factory.connect(
            config.addresses.fixedRateInterestModel,
            signer
        );
    } else {
        fixedInterestRateModel = await deployContract<FixedInterestRateModel>(
            new FixedInterestRateModel__factory(signer),
            "FixedInterestRateModel",
            [config.fixedInterestRateModel.interestRatePerBlock],
            debug,
            waitForBlocks
        );
    }

    // deploy uToken
    let uToken: UToken;
    if (config.addresses.uToken) {
        uToken = UToken__factory.connect(config.addresses.uToken, signer);
    } else {
        const {proxy} = await deployProxy<UToken>(
            new UToken__factory(signer),
            "UToken",
            {
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
            },
            debug
        );
        uToken = UToken__factory.connect(proxy.address, signer);
        await userManager.setUToken(uToken.address);
        await marketRegistry.setUToken(dai.address, uToken.address);
        await uToken.setUserManager(userManager.address);
        await uToken.setAssetManager(assetManager.address);
        await uToken.setInterestRateModel(fixedInterestRateModel.address);
    }

    // deploy pure token
    let pureToken: PureTokenAdapter;
    if (config.addresses.adapters?.pureTokenAdapter) {
        pureToken = PureTokenAdapter__factory.connect(config.addresses.adapters?.pureTokenAdapter, signer);
    } else {
        const {proxy} = await deployProxy<PureTokenAdapter>(
            new PureTokenAdapter__factory(signer),
            "PureTokenAdapter",
            {
                signature: "__PureTokenAdapter_init(address)",
                args: [assetManager.address]
            },
            debug
        );
        pureToken = PureTokenAdapter__factory.connect(proxy.address, signer);
    }

    // deploy aave v3 adapter
    let aaveV3Adapter: AaveV3Adapter | undefined = undefined;
    if (config.addresses.adapters?.aaveV3Adapter) {
        aaveV3Adapter = AaveV3Adapter__factory.connect(config.addresses.adapters?.aaveV3Adapter, signer);
    } else {
        // Only deploy the aaveV3Adapter if the lendingPool and aave market address are in the config
        if (config.addresses.aave?.lendingPool && config.addresses.aave?.market) {
            const {proxy} = await deployProxy<AaveV3Adapter>(
                new AaveV3Adapter__factory(signer),
                "AaveV3Adapter",
                {
                    signature: "__AaveV3Adapter_init(address,address,address)",
                    args: [assetManager.address, config.addresses.aave?.lendingPool, config.addresses.aave?.market]
                },
                debug
            );
            aaveV3Adapter = AaveV3Adapter__factory.connect(proxy.address, signer);
        }
    }

    if (!config.addresses.assetManager) {
        // Add pure token adapter to assetManager
        await assetManager.addToken(dai.address);
        await assetManager.addAdapter(pureToken.address);

        if (aaveV3Adapter?.address) {
            await assetManager.addAdapter(aaveV3Adapter.address);
        }
    }

    return {
        userManager,
        uToken,
        unionToken,
        marketRegistry,
        fixedInterestRateModel,
        comptroller,
        assetManager,
        dai,
        adapters: {pureToken, aaveV3Adapter}
    };
}
