import {BigNumberish, Signer, ethers} from "ethers";

import {
    AssetManager__factory,
    Comptroller,
    Comptroller__factory,
    UserManagerERC20,
    UserManagerERC20__factory,
    UErc20,
    UErc20__factory,
    AssetManager,
    PureTokenAdapter,
    PureTokenAdapter__factory,
    IUnionToken,
    IUnionToken__factory,
    FaucetERC20,
    FaucetERC20__factory,
    MarketRegistry,
    MarketRegistry__factory,
    FixedInterestRateModel,
    FixedInterestRateModel__factory,
    AaveV3Adapter,
    AaveV3Adapter__factory,
    IDai__factory,
    IDai,
    VouchFaucet,
    VouchFaucet__factory
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
    opL2Bridge?: string;
    opL1Bridge?: string;
    opL2CrossDomainMessenger?: string;
    opOwner?: string;
    opAdmin?: string;
    opUnion?: string;
}

export interface DeployConfig {
    admin: string;
    addresses: Addresses;
    userManager: {
        maxOverdue: BigNumberish;
        effectiveCount: BigNumberish;
        maxVouchers: BigNumberish;
        maxVouchees: BigNumberish;
    };
    uToken: {
        name: string;
        symbol: string;
        initialExchangeRateMantissa: BigNumberish;
        reserveFactorMantissa: BigNumberish;
        originationFee: BigNumberish;
        originationFeeMax: BigNumberish;
        debtCeiling: BigNumberish;
        maxBorrow: BigNumberish;
        minBorrow: BigNumberish;
        overdueTime: BigNumberish;
        mintFeeRate: BigNumberish;
    };
    fixedInterestRateModel: {
        interestRatePerSecond: BigNumberish;
    };
    comptroller: {
        halfDecayPoint: BigNumberish;
    };
}

export interface Contracts {
    userManager: UserManagerERC20;
    uToken: UErc20;
    fixedInterestRateModel: FixedInterestRateModel;
    comptroller: Comptroller;
    assetManager: AssetManager;
    dai: IDai | FaucetERC20;
    marketRegistry: MarketRegistry;
    unionToken: IUnionToken | FaucetERC20;
    adapters: {
        pureTokenAdapter: PureTokenAdapter;
        aaveV3Adapter?: AaveV3Adapter;
    };
    vouchFaucet?: VouchFaucet;
}

export default async function (
    config: DeployConfig,
    signer: Signer,
    debug = false,
    waitForBlocks: number | undefined = undefined,
    isTestnet: boolean = false
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
                signature: "__MarketRegistry_init(address)",
                args: [config.admin]
            },
            debug
        );
        marketRegistry = MarketRegistry__factory.connect(proxy.address, signer);
    }
    // deploy UNION
    const unionTokenAddress = config.addresses.unionToken || config.addresses.opUnion;
    let unionToken: IUnionToken | FaucetERC20;
    if (unionTokenAddress) {
        unionToken = IUnionToken__factory.connect(unionTokenAddress, signer);
    } else {
        unionToken = await deployContract<FaucetERC20>(
            new FaucetERC20__factory(signer),
            "UnionToken",
            ["Union Token", "UNION"],
            debug,
            waitForBlocks
        );
    }
    // deploy DAI
    let dai: IDai | FaucetERC20;
    if (config.addresses.dai) {
        dai = IDai__factory.connect(config.addresses.dai, signer);
    } else {
        dai = await deployContract<FaucetERC20>(
            new FaucetERC20__factory(signer),
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
            signature: "__Comptroller_init(address,address,address,uint256)",
            args: [config.admin, unionToken.address, marketRegistry.address, config.comptroller.halfDecayPoint]
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
                signature: "__AssetManager_init(address,address)",
                args: [config.admin, marketRegistry.address]
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
                signature:
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                args: [
                    assetManager.address,
                    unionToken.address,
                    dai.address,
                    comptroller.address,
                    config.admin,
                    config.userManager.maxOverdue,
                    config.userManager.effectiveCount,
                    config.userManager.maxVouchers,
                    config.userManager.maxVouchees
                ]
            },
            debug
        );
        userManager = UserManagerERC20__factory.connect(proxy.address, signer);
        const tx = await marketRegistry.setUserManager(dai.address, userManager.address);
        await tx.wait(waitForBlocks);
    }

    // deploy vouch faucet if we are deploying to a testnet
    let vouchFaucet: VouchFaucet | undefined = undefined;
    if (isTestnet) {
        vouchFaucet = await deployContract<VouchFaucet>(
            new VouchFaucet__factory(signer),
            "VouchFaucet",
            [userManager.address],
            debug,
            waitForBlocks
        );
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
            [config.fixedInterestRateModel.interestRatePerSecond],
            debug,
            waitForBlocks
        );
    }

    // deploy uToken
    let uToken: UErc20;
    if (config.addresses.uToken) {
        uToken = UErc20__factory.connect(config.addresses.uToken, signer);
    } else {
        const {proxy} = await deployProxy<UErc20>(
            new UErc20__factory(signer),
            "UErc20",
            {
                signature:
                    "__UToken_init((string name,string symbol,address underlying,uint256 initialExchangeRateMantissa,uint256 reserveFactorMantissa,uint256 originationFee,uint256 originationFeeMax,uint256 debtCeiling,uint256 maxBorrow,uint256 minBorrow,uint256 overdueTime,address admin,uint256 mintFeeRate))",
                args: [
                    {
                        name: config.uToken.name,
                        symbol: config.uToken.symbol,
                        underlying: dai.address,
                        initialExchangeRateMantissa: config.uToken.initialExchangeRateMantissa,
                        reserveFactorMantissa: config.uToken.reserveFactorMantissa,
                        originationFee: config.uToken.originationFee,
                        originationFeeMax: config.uToken.originationFeeMax,
                        debtCeiling: config.uToken.debtCeiling,
                        maxBorrow: config.uToken.maxBorrow,
                        minBorrow: config.uToken.minBorrow,
                        overdueTime: config.uToken.overdueTime,
                        admin: config.admin,
                        mintFeeRate: config.uToken.mintFeeRate
                    }
                ]
            },
            debug
        );
        uToken = UErc20__factory.connect(proxy.address, signer);

        let tx = await userManager.setUToken(uToken.address);
        await tx.wait(waitForBlocks);

        tx = await marketRegistry.setUToken(dai.address, uToken.address);
        await tx.wait(waitForBlocks);

        tx = await uToken.setUserManager(userManager.address);
        await tx.wait(waitForBlocks);

        tx = await uToken.setAssetManager(assetManager.address);
        await tx.wait(waitForBlocks);

        tx = await uToken.setInterestRateModel(fixedInterestRateModel.address);
        await tx.wait(waitForBlocks);
    }

    // deploy pure token
    let pureTokenAdapter: PureTokenAdapter;
    if (config.addresses.adapters?.pureTokenAdapter) {
        pureTokenAdapter = PureTokenAdapter__factory.connect(config.addresses.adapters?.pureTokenAdapter, signer);
    } else {
        const {proxy} = await deployProxy<PureTokenAdapter>(
            new PureTokenAdapter__factory(signer),
            "PureTokenAdapter",
            {
                signature: "__PureTokenAdapter_init(address,address)",
                args: [config.admin, assetManager.address]
            },
            debug
        );
        pureTokenAdapter = PureTokenAdapter__factory.connect(proxy.address, signer);
    }

    // deploy aave v3 adapter
    let aaveV3Adapter: AaveV3Adapter | undefined = undefined;
    if (config.addresses.adapters?.aaveV3Adapter) {
        aaveV3Adapter = AaveV3Adapter__factory.connect(config.addresses.adapters?.aaveV3Adapter, signer);
    } else {
        // Only deploy the aaveV3Adapter if the lendingPool and aave market address are in the config
        if ((config.addresses.aave?.lendingPool && config.addresses.aave?.market) != ethers.constants.AddressZero) {
            const {proxy} = await deployProxy<AaveV3Adapter>(
                new AaveV3Adapter__factory(signer),
                "AaveV3Adapter",
                {
                    signature: "__AaveV3Adapter_init(address,address,address,address)",
                    args: [
                        config.admin,
                        assetManager.address,
                        config.addresses.aave?.lendingPool,
                        config.addresses.aave?.market
                    ]
                },
                debug
            );
            aaveV3Adapter = AaveV3Adapter__factory.connect(proxy.address, signer);
        }
    }

    if (!config.addresses.assetManager) {
        // Add pure token adapter to assetManager
        let tx = await assetManager.addToken(dai.address);
        await tx.wait(waitForBlocks);

        tx = await assetManager.addAdapter(pureTokenAdapter.address);
        await tx.wait(waitForBlocks);

        if (aaveV3Adapter?.address) {
            tx = await assetManager.addAdapter(aaveV3Adapter.address);
            await tx.wait(waitForBlocks);
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
        adapters: {pureTokenAdapter, aaveV3Adapter},
        vouchFaucet
    };
}
