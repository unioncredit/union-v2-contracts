pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../market/MarketRegistry.sol";
import "../asset/AssetManager.sol";
import "../token/Comptroller.sol";
import "../market/UToken.sol";
import "../mocks/FaucetERC20.sol";
import "../token/UnionToken.sol";
import "../user/UserManager.sol";
import "../market/FixedInterestRateModel.sol";
import "../UUPSProxy.sol";

contract TestWrapper is Test {
    // Mocks
    FaucetERC20 public dai;

    AssetManager public assetManager;
    MarketRegistry public marketRegistry;
    UToken public uToken;
    UserManager public userManager;
    FixedInterestRateModel public interestRateModel;
    UnionToken public unionToken;
    Comptroller public comptroller;

    // general
    address public constant ADMIN = 0x00a329c0648769A73afAc7F9381E08FB43dBEA72;
    uint256 public constant trustAmount = 10 ether;

    // utoken
    uint256 public constant initialExchangeRateMantissa = 1000000000000000000;
    uint256 public constant reserveFactorMantissa = 1000000000000000000;
    uint256 public constant originationFee = 5000000000000000;
    uint256 public constant debtCeiling = 250000000000000000000000;
    uint256 public constant maxBorrow = 25000000000000000000000;
    uint256 public constant minBorrow = 1 ether;
    uint256 public constant overdueBlocks = 197250;

    // members
    address public constant MEMBER_1 = address(111);
    address public constant MEMBER_2 = address(222);
    address public constant MEMBER_3 = address(333);
    address public constant MEMBER_4 = address(444);

    function deployProxy(address implementation, bytes memory signature) private returns (address) {
        UUPSProxy proxy = new UUPSProxy(implementation, address(0), signature);
        return address(proxy);
    }

    function setUp() public {
        // Mocks
        dai = new FaucetERC20();
        dai.__FaucetERC20_init("Dai__Test", "Dai__Test");

        dai.mint(MEMBER_1, 1000 ether);
        dai.mint(MEMBER_2, 1000 ether);
        dai.mint(MEMBER_3, 1000 ether);
        dai.mint(address(this), 1000 ether);

        // Union
        unionToken = new UnionToken("Union__Test", "Union__Test", msg.sender, block.timestamp + 1);

        address marketRegistryLogic = address(new MarketRegistry());
        marketRegistry = MarketRegistry(
            deployProxy(marketRegistryLogic, abi.encodeWithSignature("__MarketRegistry_init()"))
        );

        address assetManagerLogic = address(new AssetManager());
        assetManager = AssetManager(
            deployProxy(
                assetManagerLogic,
                abi.encodeWithSignature("__AssetManager_init(address)", address(marketRegistry))
            )
        );

        address comptrollerLogic = address(new Comptroller());
        comptroller = Comptroller(
            deployProxy(
                comptrollerLogic,
                abi.encodeWithSignature(
                    "__Comptroller_init(address,address)",
                    address(unionToken),
                    address(marketRegistry)
                )
            )
        );

        address userManagerLogic = address(new UserManager());
        userManager = UserManager(
            deployProxy(
                userManagerLogic,
                abi.encodeWithSignature(
                    "__UserManager_init(address,address,address,address,address)",
                    address(assetManager),
                    address(unionToken),
                    address(dai),
                    address(comptroller),
                    ADMIN
                )
            )
        );

        interestRateModel = new FixedInterestRateModel(0.005e16);

        address uTokenLogic = address(new UToken());
        uToken = UToken(
            deployProxy(
                uTokenLogic,
                abi.encodeWithSignature(
                    "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
                    "UToken__Test",
                    "UToken__Test",
                    address(dai),
                    initialExchangeRateMantissa,
                    reserveFactorMantissa,
                    originationFee,
                    debtCeiling,
                    maxBorrow,
                    minBorrow,
                    overdueBlocks,
                    ADMIN
                )
            )
        );

        vm.startPrank(ADMIN);
        uToken.setAssetManager(address(assetManager));
        uToken.setInterestRateModel(address(interestRateModel));
        uToken.setUserManager(address(userManager));

        userManager.setUToken(address(uToken));

        userManager.addMember(MEMBER_1);
        userManager.addMember(MEMBER_2);
        userManager.addMember(MEMBER_3);
        vm.stopPrank();

        marketRegistry.addUToken(address(dai), address(uToken));
        marketRegistry.addUserManager(address(dai), address(userManager));

        dai.approve(address(uToken), type(uint256).max);
        uToken.addReserves(dai.balanceOf(address(this)));
    }

    function initStakers() internal {
        vm.startPrank(MEMBER_1);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(MEMBER_2);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(MEMBER_3);
        dai.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();
    }

    function registerMember(address newMember) internal {
        vm.startPrank(MEMBER_1);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        vm.startPrank(MEMBER_2);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        vm.startPrank(MEMBER_3);
        userManager.updateTrust(newMember, trustAmount);
        vm.stopPrank();

        uint256 memberFee = userManager.newMemberFee();
        unionToken.approve(address(userManager), memberFee);
        userManager.registerMember(newMember);
    }

    function testDeployment() public {
        assert(userManager.checkIsMember(MEMBER_1));
        assert(userManager.checkIsMember(MEMBER_2));
        assert(userManager.checkIsMember(MEMBER_3));
    }
}
