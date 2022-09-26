pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";

contract TestSetters is TestComptrollerBase {
    function testSetHalfDecayPoint(uint256 amount) public {
        vm.assume(amount != 0);
        comptroller.setHalfDecayPoint(amount);
        assertEq(amount, comptroller.halfDecayPoint());
    }

    function testCannotSetHalfDecayPointZero() public {
        vm.expectRevert(Comptroller.NotZero.selector);
        comptroller.setHalfDecayPoint(0);
    }

    function testCannotSetHalfDecayPointNonAdmin() public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        vm.prank(address(1));
        comptroller.setHalfDecayPoint(1);
    }

    function testUpdateTotalStaked(uint256 amount) public {
        vm.assume(amount != 0 && amount < 1_000_000 ether);

        marketRegistryMock.setUserManager(address(daiMock), address(this));
        uint256 previousBlock = block.number;
        assertEq(comptroller.gLastUpdatedBlock(), block.number);
        assertEq(comptroller.gInflationIndex(), comptroller.INIT_INFLATION_INDEX());

        vm.roll(100);
        comptroller.updateTotalStaked(address(daiMock), amount);
        assert(previousBlock != block.number);
        assertEq(comptroller.gLastUpdatedBlock(), block.number);
        assert(comptroller.gInflationIndex() != comptroller.INIT_INFLATION_INDEX());
    }

    function testCannotUpdateTotalStakedNotUserManager() public {
        marketRegistryMock.setUserManager(address(daiMock), address(1));
        vm.expectRevert(Comptroller.SenderNotUserManager.selector);
        comptroller.updateTotalStaked(address(daiMock), 1);
    }

    function testCannotSetMaxStakeAmountNonAdmin() public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        vm.prank(address(1));
        comptroller.setMaxStakeAmount(1);
    }

    function testSetMaxStakeAmount(uint96 amount) public {
        comptroller.setMaxStakeAmount(amount);
        assertEq(comptroller.maxStakeAmount(), amount);
    }

    function testCannotSetSupportUTokenNonAdmin() public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        vm.prank(address(1));
        comptroller.setSupportUToken(address(1), true);
    }

    function testSetUTokenNotEXIT(bool isSupport) public {
        vm.expectRevert(Comptroller.NotExit.selector);
        comptroller.setSupportUToken(address(daiMock), isSupport);
    }

    function testSetSupportUToken(bool isSupport) public {
        marketRegistryMock.setUToken(address(daiMock), address(uTokenMock));
        comptroller.setSupportUToken(address(daiMock), isSupport);
        assertEq(comptroller.isSupportUToken(address(uTokenMock)), isSupport);
    }
}
