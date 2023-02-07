pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";

contract TestSetters is TestComptrollerBase {
    function testSetHalfDecayPoint(uint256 amount) public {
        vm.assume(amount != 0);
        vm.prank(ADMIN);
        comptroller.setHalfDecayPoint(amount);
        assertEq(amount, comptroller.halfDecayPoint());
    }

    function testCannotSetHalfDecayPointZero() public {
        vm.prank(ADMIN);
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
        vm.prank(ADMIN);
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
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(1));
        vm.expectRevert(Comptroller.SenderNotUserManager.selector);
        comptroller.updateTotalStaked(address(daiMock), 1);
    }
}
