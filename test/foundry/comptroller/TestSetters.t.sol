pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";
import {Comptroller} from "union-v2-contracts/token/Comptroller.sol";

contract TestSetters is TestComptrollerBase {
    function testInit() public {
        address logic = address(new Comptroller());

        Comptroller comp = Comptroller(deployProxy(logic, ""));
        comp.__Comptroller_init(ADMIN, address(unionTokenMock), address(marketRegistryMock), halfDecayPoint);
        uint cHalfDecayPoint = comp.halfDecayPoint();
        assertEq(cHalfDecayPoint, halfDecayPoint);
        bool isAdmin = comp.isAdmin(ADMIN);
        assertEq(isAdmin, true);
        address cMarketRegistry = address(comp.marketRegistry());
        assertEq(cMarketRegistry, address(marketRegistryMock));
        address cUnionToken = address(comp.unionToken());
        assertEq(cUnionToken, address(unionTokenMock));
    }

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
        vm.assume(amount >= 1 ether && amount < 1_000_000 ether);

        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(this));
        assertEq(comptroller.gLastUpdated(), block.timestamp);
        assertEq(comptroller.gInflationIndex(), comptroller.INIT_INFLATION_INDEX());

        skip(100);

        comptroller.updateTotalStaked(address(erc20Mock), amount);
        assertEq(comptroller.gLastUpdated(), block.timestamp);
        assert(comptroller.gInflationIndex() != comptroller.INIT_INFLATION_INDEX());
    }

    function testCannotUpdateTotalStakedNotUserManager() public {
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(1));
        vm.expectRevert(Comptroller.SenderNotUserManager.selector);
        comptroller.updateTotalStaked(address(erc20Mock), 1);
    }
}
