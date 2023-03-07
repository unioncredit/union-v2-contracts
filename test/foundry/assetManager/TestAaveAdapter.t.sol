pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {AaveV3Adapter} from "union-v2-contracts/asset/AaveV3Adapter.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "union-v2-contracts/interfaces/aave/AMarket3.sol";
import "union-v2-contracts/interfaces/aave/LendingPool3.sol";

contract FakeAMarket3 is AMarket3 {
    function claimAllRewards(address[] calldata assets, address to) external returns (uint256) {}

    function getRewardsList() external view returns (address[] memory) {}
}

contract FakeLendingPool3 is LendingPool3 {
    function getReserveData(address asset) external view returns (ReserveData memory data) {
        data.aTokenAddress = address(11);
        return data;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {}

    function withdraw(address tokenAddress, uint256, address recipient) external returns (uint256) {
        uint256 amount = IERC20Upgradeable(tokenAddress).balanceOf(address(this));
        IERC20Upgradeable(tokenAddress).transfer(recipient, amount);

        return amount;
    }
}

contract TestAaveV3Adapter is TestWrapper {
    AaveV3Adapter public adapter;
    FakeAMarket3 public market;
    FakeLendingPool3 public lendingPool;

    address public constant ADMIN = address(0);

    function setUp() public virtual {
        address logic = address(new AaveV3Adapter());
        deployMocks();
        market = new FakeAMarket3();
        lendingPool = new FakeLendingPool3();

        adapter = AaveV3Adapter(
            deployProxy(
                logic,
                abi.encodeWithSignature(
                    "__AaveV3Adapter_init(address,address,address,address)",
                    [ADMIN, address(assetManagerMock), address(lendingPool), address(market)]
                )
            )
        );
        vm.prank(ADMIN);
        adapter.mapTokenToAToken(address(daiMock));
    }

    function supplyToken(uint256 supplyAmount) public {
        daiMock.mint(address(adapter), supplyAmount);
    }

    function testInit() public {
        address logic = address(new AaveV3Adapter());
        AaveV3Adapter _adapter;
        _adapter = AaveV3Adapter(deployProxy(logic, ""));
        _adapter.__AaveV3Adapter_init(ADMIN, address(assetManagerMock), lendingPool, market);

        bool isAdmin = _adapter.isAdmin(ADMIN);
        assertEq(isAdmin, true);
        address _assetManager = address(_adapter.assetManager());
        assertEq(_assetManager, address(assetManagerMock));
        address _lendingPool = address(_adapter.lendingPool());
        assertEq(_lendingPool, address(lendingPool));
        address _market = address(_adapter.market());
        assertEq(_market, address(market));
    }

    function testMapTokenToAToken(address token) public {
        vm.prank(ADMIN);
        vm.mockCall(
            token,
            abi.encodeWithSelector(daiMock.allowance.selector, address(adapter), address(lendingPool)),
            abi.encode(type(uint256).max)
        );
        adapter.mapTokenToAToken(address(token));
    }

    function testSetAssetManager(address assetManager) public {
        vm.prank(ADMIN);
        adapter.setAssetManager(assetManager);
        assertEq(assetManager, adapter.assetManager());
    }

    function testCannotSetAssetManagerNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        adapter.setAssetManager(address(1));
    }

    function testSetFloor(uint256 amount) public {
        vm.prank(ADMIN);
        adapter.setFloor(address(daiMock), amount);
        assertEq(adapter.floorMap(address(daiMock)), amount);
    }

    function testCannotSetFloorNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        adapter.setFloor(address(1), 0);
    }

    function testSetCeiling(uint256 amount) public {
        vm.prank(ADMIN);
        adapter.setCeiling(address(daiMock), amount);
        assertEq(adapter.ceilingMap(address(daiMock)), amount);
    }

    function testCannotSetCeilingNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        adapter.setCeiling(address(daiMock), 0);
    }

    function testGetRate() public {
        assertEq(0, adapter.getRate(address(0)));
    }

    function testGetSupply(uint256 amount) public {
        vm.assume(amount >= 1 ether);
        supplyToken(amount);
        vm.mockCall(
            address(11),
            abi.encodeWithSelector(daiMock.balanceOf.selector, address(adapter)),
            abi.encode(amount)
        );
        assertEq(amount, adapter.getSupply(address(daiMock)));
    }

    function testGetSupplyView(uint256 amount) public {
        vm.assume(amount >= 1 ether);
        supplyToken(amount);
        vm.mockCall(
            address(11),
            abi.encodeWithSelector(daiMock.balanceOf.selector, address(adapter)),
            abi.encode(amount)
        );
        assertEq(amount, adapter.getSupplyView(address(daiMock)));
    }

    function testSupportsToken() public {
        assertEq(adapter.supportsToken(address(daiMock)), true);
        assertEq(adapter.supportsToken(address(22)), false);
    }

    function testDeposit() public {
        vm.prank(address(assetManagerMock));
        adapter.deposit(address(daiMock));
    }

    function testCannotDepositUnsupportedToken() public {
        vm.expectRevert();
        adapter.deposit(address(adapter));
    }

    function testWithdraw(uint256 amount) public {
        address recipient = address(123);
        daiMock.mint(address(lendingPool), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(adapter.assetManager());
        vm.mockCall(
            address(11),
            abi.encodeWithSelector(daiMock.balanceOf.selector, address(adapter)),
            abi.encode(amount)
        );
        adapter.withdraw(address(daiMock), recipient, amount);
        assertEq(daiMock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawNonAssetManager(uint256 amount) public {
        address recipient = address(123);
        daiMock.mint(address(adapter), amount);
        vm.expectRevert(AaveV3Adapter.SenderNotAssetManager.selector);
        adapter.withdraw(address(daiMock), recipient, amount);
    }

    function testWithdrawAll(uint256 amount) public {
        vm.assume(amount >= 1 ether);
        address recipient = address(123);
        daiMock.mint(address(lendingPool), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(adapter.assetManager());
        vm.mockCall(
            address(11),
            abi.encodeWithSelector(daiMock.balanceOf.selector, address(adapter)),
            abi.encode(amount)
        );
        adapter.withdrawAll(address(daiMock), recipient);
        assertEq(daiMock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawAllNonAssetManager(address recipient, uint256 amount) public {
        daiMock.mint(address(adapter), amount);
        vm.expectRevert(AaveV3Adapter.SenderNotAssetManager.selector);
        adapter.withdrawAll(address(daiMock), recipient);
    }

    function testClaimRewards() public {
        vm.prank(ADMIN);
        adapter.claimRewards(address(daiMock), address(0));
    }
}
