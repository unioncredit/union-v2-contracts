pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {PureTokenAdapter} from "union-v2-contracts/asset/PureTokenAdapter.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestPureTokenAdapter is TestWrapper {
    PureTokenAdapter public pureTokenAdapter;

    address public constant ADMIN = address(0);

    function setUp() public virtual {
        address logic = address(new PureTokenAdapter());

        deployMocks();

        pureTokenAdapter = PureTokenAdapter(
            deployProxy(
                logic,
                abi.encodeWithSignature("__PureTokenAdapter_init(address,address)", [ADMIN, address(assetManagerMock)])
            )
        );
    }

    function supplyToken(uint256 supplyAmount) public {
        daiMock.mint(address(pureTokenAdapter), supplyAmount);
    }

    function testSetFloor() public {
        uint256 amount = svm.createUint256("amount");
        address token = svm.createAddress("token");
        vm.prank(ADMIN);
        pureTokenAdapter.setFloor(token, amount);
        assertEq(pureTokenAdapter.floorMap(token), amount);
    }

    function testSetCeiling() public {
        uint256 amount = svm.createUint256("amount");
        address token = svm.createAddress("token");
        vm.prank(ADMIN);
        pureTokenAdapter.setCeiling(token, amount);
        assertEq(pureTokenAdapter.ceilingMap(token), amount);
    }

    function testWithdraw() public {
        uint256 amount = svm.createUint256("amount");
        address recipient = address(123);
        daiMock.mint(address(pureTokenAdapter), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdraw(address(daiMock), recipient, amount);
        assertEq(daiMock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawNotEnoughBalance() public {
        uint256 amount = svm.createUint256("amount");
        vm.assume(amount > 0);
        address recipient = address(123);
        vm.prank(pureTokenAdapter.assetManager());
        bool res = pureTokenAdapter.withdraw(address(daiMock), recipient, amount);
        assertEq(res, false);
    }

    function testWithdrawAll() public {
        uint256 amount = svm.createUint256("amount");
        address recipient = address(123);
        daiMock.mint(address(pureTokenAdapter), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdrawAll(address(daiMock), recipient);
        assertEq(daiMock.balanceOf(recipient), amount);
    }
}
