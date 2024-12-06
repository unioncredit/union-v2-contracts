import {BigNumberish, Signer} from "ethers";
import {Interface} from "ethers/lib/utils";
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
    UErc20,
    UErc20__factory,
    AssetManager,
    PureTokenAdapter,
    PureTokenAdapter__factory,
    FaucetERC20,
    FaucetERC20__factory,
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
    usdc?: string;
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
    guardian?: string;
}

export interface DeployConfig {
    admin?: string;
    addresses: Addresses;
    userManager?: {
        maxOverdue?: BigNumberish;
        effectiveCount?: BigNumberish;
        maxVouchers?: BigNumberish;
        maxVouchees?: BigNumberish;
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
    fixedInterestRateModel?: {
        interestRatePerSecond?: BigNumberish;
    };
    comptroller?: {
        halfDecayPoint?: BigNumberish;
    };
    pureAdapter: {
        floor: BigNumberish;
        ceiling: BigNumberish;
    };
    aaveAdapter?: {
        floor?: BigNumberish;
        ceiling?: BigNumberish;
    };
}

export interface OpContracts {
    userManager: UserManagerOp;
    opUnion: OpUNION;
    opOwner: OpOwner;
    uToken: UErc20;
    fixedInterestRateModel: FixedInterestRateModel;
    comptroller: Comptroller;
    assetManager: AssetManager;
    underlying: IDai | FaucetERC20;
    marketRegistry: MarketRegistry;
    adapters: {
        pureTokenAdapter: PureTokenAdapter;
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
    console.log("Deploying OpUNION ...");
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
    let underlying: IDai | FaucetERC20;
    if (config.addresses.dai) {
        underlying = IDai__factory.connect(config.addresses.dai, signer);
    } else if (config.addresses.usdc) {
        underlying = FaucetERC20__factory.connect(config.addresses.usdc, signer);
    } else {
        // create a DAI mock token for testing
        underlying = await deployContract<FaucetERC20>(
            new FaucetERC20__factory(signer),
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

        const iface = new Interface([`function setGuardian(address) external`]);
        console.log("marketRegistry setGuardian");
        let encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        let tx = await opOwner.execute(marketRegistry.address, 0, encoded);
        await tx.wait(waitForBlocks);
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

        const iface = new Interface([`function setGuardian(address) external`]);
        console.log("comptroller setGuardian");
        let encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        let tx = await opOwner.execute(comptroller.address, 0, encoded);
        await tx.wait(waitForBlocks);
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

        const iface = new Interface([`function setGuardian(address) external`]);
        console.log("assetManager setGuardian");
        let encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        let tx = await opOwner.execute(assetManager.address, 0, encoded);
        await tx.wait(waitForBlocks);
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
                    underlying.address,
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

        const iface = new Interface([
            `function setUserManager(address,address) external`,
            `function setGuardian(address) external`
        ]);
        let encoded = iface.encodeFunctionData("setUserManager(address,address)", [
            underlying.address,
            userManager.address
        ]);
        let tx = await opOwner.execute(marketRegistry.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        tx = await opOwner.execute(userManager.address, 0, encoded);
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
            [config.fixedInterestRateModel.interestRatePerSecond],
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
                    "__UToken_init((string name,string symbol,address underlying,uint256 initialExchangeRateMantissa,uint256 reserveFactorMantissa,uint256 originationFee,uint256 originationFeeMax,uint256 debtCeiling,uint256 maxBorrow,uint256 minBorrow,uint256 overdueTime,address admin,uint256 mintFeeRate))",
                args: [
                    {
                        name: config.uToken.name,
                        symbol: config.uToken.symbol,
                        underlying: underlying.address,
                        initialExchangeRateMantissa: config.uToken.initialExchangeRateMantissa,
                        reserveFactorMantissa: config.uToken.reserveFactorMantissa,
                        originationFee: config.uToken.originationFee,
                        originationFeeMax: config.uToken.originationFeeMax,
                        debtCeiling: config.uToken.debtCeiling,
                        maxBorrow: config.uToken.maxBorrow,
                        minBorrow: config.uToken.minBorrow,
                        overdueTime: config.uToken.overdueTime,
                        admin: opOwner.address,
                        mintFeeRate: config.uToken.mintFeeRate
                    }
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
            `function setInterestRateModel(address) external`,
            `function setGuardian(address) external`
        ]);
        console.log("userManager setUToken");
        let encoded = iface.encodeFunctionData("setUToken(address)", [uToken.address]);
        let tx = await opOwner.execute(userManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("marketRegistry setUToken");
        encoded = iface.encodeFunctionData("setUToken(address,address)", [underlying.address, uToken.address]);
        tx = await opOwner.execute(marketRegistry.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("uToken setUserManager");
        encoded = iface.encodeFunctionData("setUserManager(address)", [userManager.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("uToken setAssetManager");
        encoded = iface.encodeFunctionData("setAssetManager(address)", [assetManager.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("uToken setInterestRateModel");
        encoded = iface.encodeFunctionData("setInterestRateModel(address)", [fixedInterestRateModel.address]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("uToken setGuardian");
        encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        tx = await opOwner.execute(uToken.address, 0, encoded);
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
                args: [opOwner.address, assetManager.address]
            },
            debug
        );
        pureTokenAdapter = PureTokenAdapter__factory.connect(proxy.address, signer);

        const iface = new Interface([
            `function setFloor(address,uint256) external`,
            `function setCeiling(address,uint256) external`,
            `function setGuardian(address) external`
        ]);
        console.log("pureTokenAdapter setFloor");
        let encoded = iface.encodeFunctionData("setFloor(address,uint256)", [
            underlying.address,
            config.pureAdapter.floor
        ]);
        let tx = await opOwner.execute(pureTokenAdapter.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("pureTokenAdapter setCeiling");
        encoded = iface.encodeFunctionData("setCeiling(address,uint256)", [
            underlying.address,
            config.pureAdapter.ceiling
        ]);
        tx = await opOwner.execute(pureTokenAdapter.address, 0, encoded);
        await tx.wait(waitForBlocks);

        console.log("pureTokenAdapter setGuardian");
        encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
        tx = await opOwner.execute(pureTokenAdapter.address, 0, encoded);
        await tx.wait(waitForBlocks);
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

            const iface = new Interface([
                `function mapTokenToAToken(address) external`,
                `function setFloor(address,uint256) external`,
                `function setCeiling(address,uint256) external`,
                `function setGuardian(address) external`
            ]);

            console.log("aaveV3Adapter mapTokenToAToken");
            let encoded = iface.encodeFunctionData("mapTokenToAToken(address)", [underlying.address]);
            let tx = await opOwner.execute(aaveV3Adapter.address, 0, encoded);
            await tx.wait(waitForBlocks);

            console.log("aaveV3Adapter setFloor");
            encoded = iface.encodeFunctionData("setFloor(address,uint256)", [
                underlying.address,
                config.aaveAdapter.floor
            ]);
            tx = await opOwner.execute(aaveV3Adapter.address, 0, encoded);
            await tx.wait(waitForBlocks);

            console.log("aaveV3Adapter setCeiling");
            encoded = iface.encodeFunctionData("setCeiling(address,uint256)", [
                underlying.address,
                config.aaveAdapter.ceiling
            ]);
            tx = await opOwner.execute(aaveV3Adapter.address, 0, encoded);
            await tx.wait(waitForBlocks);

            console.log("aaveV3Adapter setGuardian");
            encoded = iface.encodeFunctionData("setGuardian(address)", [config.addresses.guardian]);
            tx = await opOwner.execute(aaveV3Adapter.address, 0, encoded);
            await tx.wait(waitForBlocks);
        }
    }

    if (!config.addresses.assetManager) {
        const iface = new Interface([`function addToken(address) external`, `function addAdapter(address) external`]);

        // Add pure token adapter to assetManager
        let encoded = iface.encodeFunctionData("addToken(address)", [underlying.address]);
        console.log("assetManager addToken");
        let tx = await opOwner.execute(assetManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        encoded = iface.encodeFunctionData("addAdapter(address)", [pureTokenAdapter.address]);
        console.log("assetManager addAdapter pureTokenAdapter");
        tx = await opOwner.execute(assetManager.address, 0, encoded);
        await tx.wait(waitForBlocks);

        if (aaveV3Adapter?.address) {
            encoded = iface.encodeFunctionData("addAdapter(address)", [aaveV3Adapter.address]);
            console.log("assetManager addAdapter aaveV3Adapter");
            tx = await opOwner.execute(assetManager.address, 0, encoded);
            await tx.wait(waitForBlocks);
        }
    }

    // Enable the whitelist
    // console.log("[*] Enabling OpUNION's whitelisting ...");

    // if (!(await opUnion.isWhitelisted(comptroller.address))) {
    //     console.log(`    - Whitelist ${comptroller.address}`);
    //     const tx = await opUnion.whitelist(comptroller.address);
    //     await tx.wait(waitForBlocks);
    // }

    // if (!(await opUnion.isWhitelisted(userManager.address))) {
    //     console.log(`    - Whitelist ${userManager.address}`);
    //     const tx = await opUnion.whitelist(userManager.address);
    //     await tx.wait(waitForBlocks);
    // }

    // if (!(await opUnion.whitelistEnabled())) {
    //     console.log("    - Enable the whitelist");
    //     const tx = await opUnion.enableWhitelist();
    //     await tx.wait(waitForBlocks);
    // }

    if ((await opUnion.owner()) != opOwner.address) {
        // set UNION token's owner
        console.log(`    - Transfer UNION token's ownership to ${opOwner.address}`);
        const tx = await opUnion.transferOwnership(opOwner.address);
        await tx.wait(waitForBlocks);
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
        underlying,
        adapters: {pureTokenAdapter, aaveV3Adapter}
    };
}
