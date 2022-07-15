pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";

contract TestSetters is TestComptrollerBase {
    function testSetHalfDecayPoint(uint256 amount) public {
        vm.assume(amount != 0);
        comptroller.setHalfDecayPoint(amount);
        assertEq(amount, comptroller.halfDecayPoint());
    }

    function testCannotSetHalfDecayPointZero() public {
        vm.expectRevert("Comptroller: halfDecayPoint can not be zero");
        comptroller.setHalfDecayPoint(0);
    }

    function testCannotSetHalfDecayPointNonAdmin() public {
        vm.expectRevert("Controller: not admin");
        vm.prank(address(1));
        comptroller.setHalfDecayPoint(1);
    }

    function testUpdateTotalStaked(uint256 amount) public {
      vm.assume(amount != 0 && amount < 1_000_000 ether);

      marketRegistryMock.setTokens(address(this), address(this));
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
      marketRegistryMock.setTokens(address(1), address(1));
      vm.expectRevert("UnionToken: only user manager can call");
      comptroller.updateTotalStaked(address(daiMock), 1);
    }
}
