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
        erc20Mock.mint(address(pureTokenAdapter), supplyAmount);
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
        assertEq(amount, pureTokenAdapter.getSupply(address(erc20Mock)));
    }

    function testGetSupplyView(uint256 amount) public {
        supplyToken(amount);
        assertEq(amount, pureTokenAdapter.getSupplyView(address(erc20Mock)));
    }

    function testSupportsToken() public {
        vm.expectRevert();
        pureTokenAdapter.supportsToken(address(pureTokenAdapter));
        assert(pureTokenAdapter.supportsToken(address(erc20Mock)));
    }

    function testDeposit() public {
        // nothing to assert just check this passes
        pureTokenAdapter.deposit(address(erc20Mock));
    }

    function testCannotDepositUnsupportedToken() public {
        vm.expectRevert();
        pureTokenAdapter.deposit(address(pureTokenAdapter));
    }

    function testWithdraw(uint256 amount) public {
        address recipient = address(123);
        erc20Mock.mint(address(pureTokenAdapter), amount);
        assertEq(erc20Mock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdraw(address(erc20Mock), recipient, amount);
        assertEq(erc20Mock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawNonAssetManager(uint256 amount) public {
        address recipient = address(123);
        erc20Mock.mint(address(pureTokenAdapter), amount);
        vm.expectRevert(PureTokenAdapter.SenderNotAssetManager.selector);
        pureTokenAdapter.withdraw(address(erc20Mock), recipient, amount);
    }

    function testCannotWithdrawNotEnoughBalance(uint256 amount) public {
        vm.assume(amount > 0);
        address recipient = address(123);
        vm.prank(pureTokenAdapter.assetManager());
        bool res = pureTokenAdapter.withdraw(address(erc20Mock), recipient, amount);
        assertEq(res, false);
    }

    function testWithdrawAll(uint256 amount) public {
        address recipient = address(123);
        erc20Mock.mint(address(pureTokenAdapter), amount);
        assertEq(erc20Mock.balanceOf(recipient), 0);
        vm.prank(pureTokenAdapter.assetManager());
        pureTokenAdapter.withdrawAll(address(erc20Mock), recipient);
        assertEq(erc20Mock.balanceOf(recipient), amount);
    }

    function testCannotWithdrawAllNonAssetManager(address recipient, uint256 amount) public {
        erc20Mock.mint(address(pureTokenAdapter), amount);
        vm.expectRevert(PureTokenAdapter.SenderNotAssetManager.selector);
        pureTokenAdapter.withdrawAll(address(erc20Mock), recipient);
    }

    function testClaimRewards() public {
        // nothing to assert just check this passes
        vm.prank(ADMIN);
        pureTokenAdapter.claimRewards(address(erc20Mock), address(0));
    }
}
