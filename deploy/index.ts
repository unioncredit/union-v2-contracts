import {BigNumberish, Signer} from "ethers";

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
    MarketRegistry__factory,
    FixedInterestRateModel,
    FixedInterestRateModel__factory
} from "../typechain-types";
const {ethers, upgrades} = require("hardhat");

const DEBUG = false;

interface Addresses {
    userManager?: string;
    uToken?: string;
    unionToken?: string;
    dai?: string;
    marketRegistry?: string;
    fixedRateInterestModel?: string;
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
        maxOverdue: BigNumberish;
        effectiveCount: BigNumberish;
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
    userManager: UserManager;
    uToken: UToken;
    fixedInterestRateModel: FixedInterestRateModel;
    comptroller: Comptroller;
    assetManager: AssetManager;
    dai: ERC20 | FaucetERC20;
    marketRegistry: MarketRegistry;
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
        const proxy = await upgrades.deployProxy(new MarketRegistry__factory(signer), [], {
            kind: "uups",
            initializer: "__MarketRegistry_init"
        });
        await proxy.deployed();
        marketRegistry = MarketRegistry__factory.connect(proxy.address, signer);
    }

    // deploy UNION
    let unionToken: IUnionToken | FaucetERC20_ERC20Permit;
    if (config.addresses.unionToken) {
        unionToken = IUnionToken__factory.connect(config.addresses.unionToken, signer);
    } else {
        const contractFactory = new FaucetERC20_ERC20Permit__factory(signer);
        unionToken = await contractFactory.deploy("Union Token", "UNION");
        if (DEBUG) {
            console.log(
                [
                    `[*] Deploying ${"UNION"}`,
                    `    - hash: ${unionToken.deployTransaction.hash}`,
                    `    - from: ${unionToken.deployTransaction.from}`,
                    `    - gas price: ${unionToken.deployTransaction.gasPrice?.toNumber() || 0 / 1e9} Gwei`
                ].join("\n")
            );
        }
    }

    // deploy DAI
    let dai: ERC20 | FaucetERC20;
    if (config.addresses.dai) {
        dai = ERC20__factory.connect(config.addresses.dai, signer);
    } else {
        const contractFactory = new FaucetERC20__factory(signer);
        dai = await contractFactory.deploy("DAI", "DAI");
        if (DEBUG) {
            console.log(
                [
                    `[*] Deploying ${"DAI"}`,
                    `    - hash: ${dai.deployTransaction.hash}`,
                    `    - from: ${dai.deployTransaction.from}`,
                    `    - gas price: ${dai.deployTransaction.gasPrice?.toNumber() || 0 / 1e9} Gwei`
                ].join("\n")
            );
        }
    }

    // deploy comptroller
    let comptroller: Comptroller;
    if (config.addresses.comptroller) {
        comptroller = Comptroller__factory.connect(config.addresses.comptroller, signer);
    } else {
        const proxy = await upgrades.deployProxy(
            new Comptroller__factory(signer),
            [unionToken.address, marketRegistry.address, config.comptroller.halfDecayPoint],
            {kind: "uups", initializer: "__Comptroller_init"}
        );
        await proxy.deployed();
        comptroller = Comptroller__factory.connect(proxy.address, signer);
    }
    // deploy asset manager
    let assetManager: AssetManager;
    if (config.addresses.assetManager) {
        assetManager = AssetManager__factory.connect(config.addresses.assetManager, signer);
    } else {
        const proxy = await upgrades.deployProxy(new AssetManager__factory(signer), [marketRegistry.address], {
            kind: "uups",
            initializer: "__AssetManager_init"
        });
        await proxy.deployed();
        assetManager = AssetManager__factory.connect(proxy.address, signer);
    }
    // deploy pure token
    let pureToken: PureTokenAdapter;
    if (config.addresses.adapters?.pureTokenAdapter) {
        pureToken = PureTokenAdapter__factory.connect(config.addresses.adapters?.pureTokenAdapter, signer);
    } else {
        const proxy = await upgrades.deployProxy(new PureTokenAdapter__factory(signer), [assetManager.address], {
            kind: "uups",
            initializer: "__PureTokenAdapter_init"
        });
        await proxy.deployed();
        pureToken = PureTokenAdapter__factory.connect(proxy.address, signer);
    }
    // deploy user manager
    let userManager: UserManager;
    if (config.addresses.userManager) {
        userManager = UserManager__factory.connect(config.addresses.userManager, signer);
    } else {
        const proxy = await upgrades.deployProxy(
            new UserManager__factory(signer),
            [
                assetManager.address,
                unionToken.address,
                dai.address,
                comptroller.address,
                config.admin,
                config.userManager.maxOverdue,
                config.userManager.effectiveCount
            ],
            {
                kind: "uups",
                initializer: "__UserManager_init"
            }
        );
        await proxy.deployed();
        userManager = UserManager__factory.connect(proxy.address, signer);
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
        const contractFactory = new FixedInterestRateModel__factory(signer);
        fixedInterestRateModel = await contractFactory.deploy(config.fixedInterestRateModel.interestRatePerBlock);
        if (DEBUG) {
            console.log(
                [
                    `[*] Deploying ${"FixedInterestRateModel"}`,
                    `    - hash: ${fixedInterestRateModel.deployTransaction.hash}`,
                    `    - from: ${fixedInterestRateModel.deployTransaction.from}`,
                    `    - gas price: ${fixedInterestRateModel.deployTransaction.gasPrice?.toNumber() || 0 / 1e9} Gwei`
                ].join("\n")
            );
        }
    }
    // deploy uToken
    let uToken: UToken;
    if (config.addresses.uToken) {
        uToken = UToken__factory.connect(config.addresses.uToken, signer);
    } else {
        const proxy = await upgrades.deployProxy(
            new UToken__factory(signer),
            [
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
            ],
            {
                kind: "uups",
                initializer: "__UToken_init"
            }
        );
        await proxy.deployed();
        uToken = UToken__factory.connect(proxy.address, signer);
        await userManager.setUToken(uToken.address);
        await marketRegistry.setUToken(dai.address, uToken.address);
        await uToken.setUserManager(userManager.address);
        await uToken.setAssetManager(assetManager.address);
        await uToken.setInterestRateModel(fixedInterestRateModel.address);
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
        adapters: {pureToken}
    };
}
