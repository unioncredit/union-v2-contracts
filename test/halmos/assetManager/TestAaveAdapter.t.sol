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

    function testSetFloor() public {
        uint256 amount = svm.createUint256("amount");
        vm.prank(ADMIN);
        adapter.setFloor(address(daiMock), amount);
        assertEq(adapter.floorMap(address(daiMock)), amount);
    }

    function testSetCeiling() public {
        uint256 amount = svm.createUint256("amount");
        vm.prank(ADMIN);
        adapter.setCeiling(address(daiMock), amount);
        assertEq(adapter.ceilingMap(address(daiMock)), amount);
    }
}
