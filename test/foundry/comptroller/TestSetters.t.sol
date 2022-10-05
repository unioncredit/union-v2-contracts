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

    function testupdateRewardIndex(uint256 amount) public {
        vm.assume(amount != 0 && amount < 1_000_000 ether);

        marketRegistryMock.setUserManager(address(daiMock), address(this));
        uint256 previousBlock = block.number;
        assertEq(comptroller.gLastUpdatedBlock(), block.number);
        assertEq(comptroller.gRewardIndex(), comptroller.INIT_REWARD_INDEX());

        vm.roll(100);
        comptroller.updateRewardIndex(address(daiMock), amount);
        assert(previousBlock != block.number);
        assertEq(comptroller.gLastUpdatedBlock(), block.number);
        assert(comptroller.gRewardIndex() != comptroller.INIT_REWARD_INDEX());
    }

    function testCannotupdateRewardIndexNotUserManager() public {
        marketRegistryMock.setUserManager(address(daiMock), address(1));
        vm.expectRevert(Comptroller.SenderNotUserManager.selector);
        comptroller.updateRewardIndex(address(daiMock), 1);
    }
}
