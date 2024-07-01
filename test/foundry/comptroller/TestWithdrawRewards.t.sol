pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {FakeUserManager} from "./FakeUserManager.sol";

contract TestWithdrawRewards is TestComptrollerBase {
    function setUp() public override {
        super.setUp();
        unionTokenMock.mint(address(comptroller), 1_000_000 ether);
    }

    function testWithdrawRewards() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um));
        uint256 balanceBefore = unionTokenMock.balanceOf(address(this));

        comptroller.withdrawRewards(address(this), address(erc20Mock));
        skip(100);
        comptroller.withdrawRewards(address(this), address(erc20Mock));

        uint256 balanceAfter = unionTokenMock.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);
    }
}
