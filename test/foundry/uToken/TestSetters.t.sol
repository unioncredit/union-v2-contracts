pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestSetters is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotSetAssetManagerNotAdmin(address assetManager) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setAssetManager(assetManager);
    }

    function testSetAssetManager(address assetManager) public {
        vm.assume(assetManager != address(0));
        vm.startPrank(ADMIN);
        uToken.setAssetManager(assetManager);
        vm.stopPrank();

        address uTokenAssetMgr = uToken.assetManager();
        assertEq(uTokenAssetMgr, assetManager);
    }

    function testCannotSetUserManagerNotAdmin(address userManager) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setUserManager(userManager);
    }

    function testSetUserManager(address userManager) public {
        vm.assume(userManager != address(0));
        vm.startPrank(ADMIN);
        uToken.setUserManager(userManager);
        vm.stopPrank();

        address uTokenUserMgr = uToken.userManager();
        assertEq(uTokenUserMgr, userManager);
    }

    function testCannotSetOriginationFeeNotAdmin(uint256 originationFee) public {
        vm.assume(originationFee <= uToken.originationFeeMax());
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setOriginationFee(originationFee);
    }

    function testCannotSetOriginationFeeAboveMax(uint256 originationFee) public {
        vm.assume(originationFee > uToken.originationFeeMax());
        vm.startPrank(ADMIN);
        vm.expectRevert(UToken.OriginationFeeExceedLimit.selector);
        uToken.setOriginationFee(originationFee);
        vm.stopPrank();
    }

    function testSetOriginationFee(uint256 originationFee) public {
        vm.assume(originationFee <= uToken.originationFeeMax());
        vm.startPrank(ADMIN);
        uToken.setOriginationFee(originationFee);
        vm.stopPrank();
        uint256 newOriginationFee = uToken.originationFee();
        assertEq(newOriginationFee, originationFee);
    }

    function testCannotSetDebtCeilingNotAdmin(uint256 debtCeiling) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setDebtCeiling(debtCeiling);
    }

    function testSetDebtCeiling(uint256 debtCeiling) public {
        vm.startPrank(ADMIN);
        uToken.setDebtCeiling(debtCeiling);
        vm.stopPrank();
        uint256 newDebtCeiling = uToken.debtCeiling();
        assertEq(newDebtCeiling, debtCeiling);
    }

    function testCannotSetMinBorrowNotAdmin(uint256 minBorrow) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setMinBorrow(minBorrow);
    }

    function testSetMinBorrow(uint256 minBorrow) public {
        vm.startPrank(ADMIN);
        uToken.setMinBorrow(minBorrow);
        vm.stopPrank();
        uint256 newMinBorrow = uToken.minBorrow();
        assertEq(newMinBorrow, minBorrow);
    }

    function testCannotSetMaxBorrowNotAdmin(uint256 maxBorrow) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setMaxBorrow(maxBorrow);
    }

    function testSetMaxBorrow(uint256 maxBorrow) public {
        vm.startPrank(ADMIN);
        uToken.setMaxBorrow(maxBorrow);
        vm.stopPrank();
        uint256 newMaxBorrow = uToken.maxBorrow();
        assertEq(newMaxBorrow, maxBorrow);
    }

    function testCannotSetOverdueBlocksNotAdmin(uint256 overdueBlocks) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setOverdueBlocks(overdueBlocks);
    }

    function testSetOverdueBlocks(uint256 overdueBlocks) public {
        vm.startPrank(ADMIN);
        uToken.setOverdueBlocks(overdueBlocks);
        vm.stopPrank();
        uint256 newOverdueBlocks = uToken.overdueBlocks();
        assertEq(newOverdueBlocks, overdueBlocks);
    }

    function testCannotSetInterestRateModelNotAdmin(address interestRateModel) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setInterestRateModel(interestRateModel);
    }

    function testSetInterestRateModels() public {
        vm.startPrank(ADMIN);
        uToken.setInterestRateModel(address(interestRateMock));
        vm.stopPrank();
        address newInterestRateModel = address(uToken.interestRateModel());
        assertEq(newInterestRateModel, address(interestRateMock));
    }

    function testCannotSetReserveFactorNotAdmin(uint256 reserveFactorMantissa) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        uToken.setReserveFactor(reserveFactorMantissa);
    }

    function testCannotSetReserveFactorExceedLimit(uint256 reserveFactorMantissa) public {
        vm.assume(reserveFactorMantissa > 1e18);
        vm.startPrank(ADMIN);
        vm.expectRevert(UToken.ReserveFactoryExceedLimit.selector);
        uToken.setReserveFactor(reserveFactorMantissa);
        vm.stopPrank();
    }

    function testSetReserveFactorModels(uint256 reserveFactorMantissa) public {
        vm.assume(reserveFactorMantissa <= 1e18);
        vm.startPrank(ADMIN);
        uToken.setReserveFactor(reserveFactorMantissa);
        vm.stopPrank();
        uint256 newReserveFactorMantissa = uToken.reserveFactorMantissa();
        assertEq(newReserveFactorMantissa, reserveFactorMantissa);
    }
}
