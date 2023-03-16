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

    function testSetAssetManager(address assetManager) public {
        vm.prank(ADMIN);
        pureTokenAdapter.setAssetManager(assetManager);
        assertEq(assetManager, pureTokenAdapter.assetManager());
    }

    function testCannotSetAssetManagerNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        pureTokenAdapter.setAssetManager(address(1));
    }

    function testSetFloor(address token, uint256 amount) public {
        vm.prank(ADMIN);
        pureTokenAdapter.setFloor(token, amount);
        assertEq(pureTokenAdapter.floorMap(token), amount);
    }

    function testCannotSetFloorNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        pureTokenAdapter.setFloor(address(1), 0);
    }

    function testSetCeiling(address token, uint256 amount) public {
        vm.prank(ADMIN);
        pureTokenAdapter.setCeiling(token, amount);
        assertEq(pureTokenAdapter.ceilingMap(token), amount);
    }

    function testCannotSetCeilingNonAdmin() public {
        vm.prank(address(1));
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        pureTokenAdapter.setCeiling(address(1), 0);
    }

    function testGetRate() public {
        assertEq(0, pureTokenAdapter.getRate(address(0)));
    }

    function testGetSupply(uint256 amount) public {
        supplyToken(amount);
        assertEq(amount, pureTokenAdapter.getSupply(address(daiMock)));
    }

    function testGetSupplyView(uint256 amount) public {
        supplyToken(amount);
        assertEq(amount, pureTokenAdapter.getSupplyView(address(daiMock)));
    }

    function testSupportsToken() public {
        vm.expectRevert();
        pureTokenAdapter.supportsToken(address(pureTokenAdapter));
        assert(pureTokenAdapter.supportsToken(address(daiMock)));
    }

    function testDeposit() public {
        // nothing to assert just check this passes
        pureTokenAdapter.deposit(address(daiMock));
    }

    function testCannotDepositUnsupportedToken() public {
        vm.expectRevert();
        pureTokenAdapter.deposit(address(pureTokenAdapter));
    }

    function testWithdraw(uint256 amount) public {
        address recipient = address(123);
        daiMock.mint(address(pureTokenAdapter), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdraw(address(daiMock), recipient, amount);
        assertEq(daiMock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawNonAssetManager(uint256 amount) public {
        address recipient = address(123);
        daiMock.mint(address(pureTokenAdapter), amount);
        vm.expectRevert(PureTokenAdapter.SenderNotAssetManager.selector);
        pureTokenAdapter.withdraw(address(daiMock), recipient, amount);
    }

    function testCannotWithdrawNotEnoughBalance(uint256 amount) public {
        vm.assume(amount > 0);
        address recipient = address(123);
        vm.prank(pureTokenAdapter.assetManager());
        bool res = pureTokenAdapter.withdraw(address(daiMock), recipient, amount);
        assertEq(res, false);
    }

    function testWithdrawAll(uint256 amount) public {
        address recipient = address(123);
        daiMock.mint(address(pureTokenAdapter), amount);
        assertEq(daiMock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdrawAll(address(daiMock), recipient);
        assertEq(daiMock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawAllNonAssetManager(address recipient, uint256 amount) public {
        daiMock.mint(address(pureTokenAdapter), amount);
        vm.expectRevert(PureTokenAdapter.SenderNotAssetManager.selector);
        pureTokenAdapter.withdrawAll(address(daiMock), recipient);
    }

    function testClaimRewards() public {
        // nothing to assert just check this passes
        vm.prank(ADMIN);
        pureTokenAdapter.claimRewards(address(daiMock), address(0));
    }
}
