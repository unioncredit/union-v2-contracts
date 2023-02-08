import {BigNumberish, Signer} from "ethers";
import {formatUnits, Interface} from "ethers/lib/utils";
import {
    AssetManager__factory,
    Comptroller,
    Comptroller__factory,
    UserManagerOp,
    UserManagerOp__factory,
    OpUNION,
    OpUNION__factory,
    OpOwner,
    OpOwner__factory,
    UToken,
    UToken__factory,
    UDai,
    UDai__factory,
    UErc20,
    UErc20__factory,
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
    dai?: string;
    marketRegistry?: string;
    fixedRateInterestModel?: string;
    comptroller?: string;
    assetManager?: string;
    opOwner?: string;
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
    unionToken?: string;
    opL2Bridge?: string;
    opL1Bridge?: string;
    opL2CrossDomainMessenger?: string;
    timelock?: string;
    opAdminAddress?: string;
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
        overdueBlocks: BigNumberish;
    };
    fixedInterestRateModel: {
        interestRatePerBlock: BigNumberish;
    };
    comptroller: {
        halfDecayPoint: BigNumberish;
    };
}

export interface OpContracts {
    userManager: UserManagerOp;
    opUnion?: OpUNION;
    opOwner?: OpOwner;
    uToken: UErc20;
    fixedInterestRateModel: FixedInterestRateModel;
    comptroller: Comptroller;
    assetManager: AssetManager;
    dai: IDai | FaucetERC20_ERC20Permit;
    marketRegistry: MarketRegistry;
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
): Promise<OpContracts> {
    // deploy opUnion
    let opUnion: OpUNION;
    if (config.addresses.opUnion) {
        opUnion = OpUNION__factory.connect(config.addresses.opUnion, signer);
    } else {
        opUnion = await deployContract<OpUNION>(
            new OpUNION__factory(signer),
            "OpUNION",
            [config.addresses.opL2Bridge, config.addresses.unionToken],
            debug,
            waitForBlocks
        );
    }

    // deploy opOwner
    let opOwner: OpOwner;
    if (config.addresses.opOwner) {
        opOwner = OpOwner__factory.connect(config.addresses.opOwner, signer);
    } else {
        opOwner = await deployContract<OpOwner>(
            new OpOwner__factory(signer),
            "OpOwner",
            [config.admin, config.addresses.timelock, config.addresses.opL2CrossDomainMessenger],
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
                args: [opOwner.address]
            },
            debug
        );
        marketRegistry = MarketRegistry__factory.connect(proxy.address, signer);
    }

    // deploy comptroller
    let comptroller: Comptroller;
    if (config.addresses.comptroller) {
        comptroller = Comptroller__factory.connect(config.addresses.comptroller, signer);
    } else {
        const {proxy} = await deployProxy<Comptroller>(
            new Comptroller__factory(signer),
            "Comptroller",
            {
                signature: "__Comptroller_init(address,address,address,uint256)",
                args: [opOwner.address, opUnion.address, marketRegistry.address, config.comptroller.halfDecayPoint]
            },
            debug
        );
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
                args: [opOwner.address, marketRegistry.address]
            },
            debug
        );
        assetManager = AssetManager__factory.connect(proxy.address, signer);
    }

    // deploy user manager
    let userManager: UserManagerOp;
    if (config.addresses.userManager) {
        userManager = UserManagerOp__factory.connect(config.addresses.userManager, signer);
    } else {
        const {proxy} = await deployProxy<UserManagerOp>(
            new UserManagerOp__factory(signer),
            "UserManagerOp",
            {
                signature:
                    "__UserManager_init(address,address,address,address,address,uint256,uint256,uint256,uint256)",
                args: [
                    assetManager.address,
                    opUnion.address,
                    dai.address,
                    comptroller.address,
                    opOwner.address,
                    config.userManager.maxOverdue,
                    config.userManager.effectiveCount,
                    config.userManager.maxVouchers,
                    config.userManager.maxVouchees
                ]
            },
            debug
        );
        userManager = UserManagerOp__factory.connect(proxy.address, signer);

        const iface = new Interface([`function setUserManager(address,address) external`]);
        const encoded = iface.encodeFunctionData("setUserManager(address,address)", [dai.address, userManager.address]);
        const tx = await opOwner.execute(marketRegistry.address, 0, encoded);
        await tx.wait(waitForBlocks);
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
        let tx = await fixedInterestRateModel.transferOwnership(opOwner.address);
        await tx.wait(waitForBlocks);
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
                    "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
                args: [
                    config.uToken.name,
                    config.uToken.symbol,
                    dai.address,
                    config.uToken.initialExchangeRateMantissa,
                    config.uToken.reserveFactorMantissa,
                    config.uToken.originationFee,
                    config.uToken.originationFeeMax,
                    config.uToken.debtCeiling,
                    config.uToken.maxBorrow,
                    config.uToken.minBorrow,
                    config.uToken.overdueBlocks,
                    opOwner.address
                ]
            },
            debug
        );
        uToken = UErc20__factory.connect(proxy.address, signer);

        const iface = new Interface([
            `function setUToken(address) external`,
            `function setUToken(address,address) external`,
            `function setUserManager(address) external`,
            `function setAssetManager(address) external`,
            `function setInterestRateModel(address) external`
        ]);

        let encoded = iface.encodeFunctionData("setUToken(address)", [uToken.address]);
        let tx = await opOwner.execute(userManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("setUToken(address,address)", [dai.address, uToken.address]);
        tx = await opOwner.execute(marketRegistry.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("setUserManager(address)", [userManager.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("setAssetManager(address)", [assetManager.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("setInterestRateModel(address)", [fixedInterestRateModel.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);
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
                signature: "__PureTokenAdapter_init(address,address)",
                args: [opOwner.address, assetManager.address]
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
                    signature: "__AaveV3Adapter_init(address,address,address,address)",
                    args: [
                        opOwner.address,
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
        const iface = new Interface([`function addToken(address) external`, `function addAdapter(address) external`]);

        // Add pure token adapter to assetManager
        let encoded = iface.encodeFunctionData("addToken(address)", [dai.address]);
        let tx = await opOwner.execute(assetManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("addAdapter(address)", [pureToken.address]);
        tx = await opOwner.execute(assetManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        if (aaveV3Adapter?.address) {
            encoded = iface.encodeFunctionData("addAdapter(address)", [aaveV3Adapter.address]);
            tx = await opOwner.execute(assetManager.address, 0, encoded);
            await tx.wait(waitForBlocks);
        }
    }

    return {
        opUnion,
        opOwner,
        userManager,
        uToken,
        marketRegistry,
        fixedInterestRateModel,
        comptroller,
        assetManager,
        dai,
        adapters: {pureToken, aaveV3Adapter}
    };
}
