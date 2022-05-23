const {ethers, upgrades} = require("hardhat");

const deployAndInitDAI = async () => {
    return upgrades.deployProxy(
        await ethers.getContractFactory("FaucetERC20"),
        ["Dai Stablecoin", "DAI"], //Must be "Dai Stablecoin" or permit signature verification will fail
        {initializer: "__FaucetERC20_init(string,string)"}
    );
};

const deployAndInitUnionToken = async ({timelock}) => {
    const latestBlock = await ethers.provider.getBlock("latest");
    const UnionToken = await ethers.getContractFactory("UnionToken");
    return await UnionToken.deploy("Union Token", "Union", timelock.address, latestBlock.timestamp + 100);
};

const deployAndInitFixedInterestRateModel = async () => {
    const FixedInterestRateModel = await ethers.getContractFactory("FixedInterestRateModel");
    return await FixedInterestRateModel.deploy(ethers.utils.parseEther("0.000001"));
};

const deployAndInitSumOfTrust = async () => {
    const SumOfTrust = await ethers.getContractFactory("SumOfTrust");
    return await SumOfTrust.deploy(3);
};

const deployMarketRegistry = async () => {
    return upgrades.deployProxy(await ethers.getContractFactory("MarketRegistry"), {
        initializer: "__MarketRegistry_init()"
    });
};

const deployAndInitTimelock = async () => {
    const [admin] = await ethers.getSigners();
    const Timelock = await ethers.getContractFactory("TimelockController");
    return await Timelock.deploy(0, [admin.address], [admin.address]);
};

const deployAndInitComptroller = async ({unionToken, marketRegistry}) => {
    return upgrades.deployProxy(
        await ethers.getContractFactory("Comptroller"),
        [unionToken.address, marketRegistry.address],
        {initializer: "__Comptroller_init(address,address)"}
    );
};

const deployAndInitAssetManager = async ({marketRegistry}) => {
    return upgrades.deployProxy(await ethers.getContractFactory("AssetManager"), [marketRegistry.address], {
        initializer: "__AssetManager_init(address)"
    });
};

const deployAndInitUToken = async ({dai}) => {
    const [admin] = await ethers.getSigners();

    return upgrades.deployProxy(
        await ethers.getContractFactory("UToken"),
        [
            "UToken",
            "UToken",
            dai.address,
            ethers.utils.parseEther("1"), // initialExchangeRateMantissa
            ethers.utils.parseEther("0.5"), // reserveFactorMantissa
            ethers.utils.parseEther("0.01"), // originationFee, 1%
            ethers.utils.parseEther("1000"), // debtCeiling
            ethers.utils.parseEther("1000"), // maxBorrow
            ethers.utils.parseEther("1"), // minBorrow
            10, // overdueBlocks,
            admin.address
        ],
        {
            initializer:
                "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)"
        }
    );
};

const deployAndInitUserManager = async ({assetManager, unionToken, dai, sumOfTrust, comptroller}) => {
    const [admin] = await ethers.getSigners();
    return upgrades.deployProxy(
        await ethers.getContractFactory("UserManager"),
        [assetManager.address, unionToken.address, dai.address, sumOfTrust.address, comptroller.address, admin.address],
        {initializer: "__UserManager_init(address,address,address,address,address,address)"}
    );
};

const initMarketRegistry = async ({marketRegistry, dai, uToken, userManager}) => {
    await marketRegistry.deleteMarket(dai.address);
    await marketRegistry.addUToken(dai.address, uToken.address);
    await marketRegistry.addUserManager(dai.address, userManager.address);
};

const initUToken = async ({uToken, assetManager, fixedInterestRateModel, userManager}) => {
    await uToken.setAssetManager(assetManager.address);
    await uToken.setInterestRateModel(fixedInterestRateModel.address);
    await uToken.setUserManager(userManager.address);
};

const initUserManager = async ({userManager, uToken}) => {
    await userManager.setUToken(uToken.address);
};

const deployFullSuite = async () => {
    const dai = await deployAndInitDAI();
    const timelock = await deployAndInitTimelock();
    const unionToken = await deployAndInitUnionToken({timelock});
    const fixedInterestRateModel = await deployAndInitFixedInterestRateModel();
    const sumOfTrust = await deployAndInitSumOfTrust();
    const marketRegistry = await deployMarketRegistry();
    const comptroller = await deployAndInitComptroller({unionToken, marketRegistry});
    const assetManager = await deployAndInitAssetManager({marketRegistry});
    const uToken = await deployAndInitUToken({dai});
    const userManager = await deployAndInitUserManager({assetManager, unionToken, dai, sumOfTrust, comptroller});

    await initMarketRegistry({marketRegistry, dai, uToken, userManager});
    await initUToken({uToken, assetManager, fixedInterestRateModel, userManager});
    await initUserManager({userManager, uToken});
    await unionToken.whitelist(comptroller.address);
    return {
        dai,
        unionToken,
        fixedInterestRateModel,
        sumOfTrust,
        comptroller,
        marketRegistry,
        assetManager,
        uToken,
        userManager
    };
};

module.exports = {
    deployAndInitDAI,
    deployAndInitUnionToken,
    deployAndInitFixedInterestRateModel,
    deployAndInitSumOfTrust,
    deployAndInitComptroller,
    deployMarketRegistry,
    deployAndInitAssetManager,
    deployAndInitUToken,
    deployAndInitUserManager,
    deployAndInitTimelock,
    initMarketRegistry,
    initUToken,
    initUserManager,
    deployFullSuite
};
