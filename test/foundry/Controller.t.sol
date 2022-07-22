pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {Controller} from "union-v1.5-contracts/Controller.sol";

contract FakeController is Controller {}

contract TestController is TestWrapper {
    Controller public controller;
    address public constant ADMIN = address(1);

    function setUp() public virtual {
        address controllerLogic = address(new FakeController());

        controller = FakeController(
            deployProxy(controllerLogic, abi.encodeWithSignature("__Controller_init(address)", [ADMIN]))
        );
    }

    function testIsAdmin() public {
        assertEq(controller.isAdmin(address(1)), true);
        assertEq(controller.isAdmin(address(2)), false);
    }

    function testCannotSetPendingAdminZeroAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert("Controller: address zero");
        controller.setPendingAdmin(address(0));
    }

    function testSetPendingAdmin(address account) public {
        vm.assume(account != address(0));
        vm.prank(ADMIN);
        controller.setPendingAdmin(account);
        address pendingAdmin = controller.pendingAdmin();
        assertEq(pendingAdmin, account);
    }

    function testCannotAcceptAdminNonPendingAdminr() public {
        vm.expectRevert("Controller: not pending admin");
        controller.acceptAdmin();
    }

    function testAcceptAdmin() public {
        address pendingAdmin = controller.pendingAdmin();
        vm.prank(pendingAdmin);
        controller.acceptAdmin();
        address admin = controller.admin();
        assertEq(admin, pendingAdmin);
    }

    function testCannotSetGuardianNonAdmin(address account) public {
        vm.expectRevert("Controller: not admin");
        controller.setGuardian(account);
    }

    function testSetGuardian(address account) public {
        vm.prank(ADMIN);
        controller.setGuardian(account);
        address pauseGuardian = controller.pauseGuardian();
        assertEq(pauseGuardian, account);
    }

    function testCannotPauseNonPauseGuardian() public {
        vm.expectRevert("Controller: caller does not have the guardian role");
        controller.pause();
    }

    function testCannotPauseWhenPaused() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        controller.pause();
        vm.expectRevert("Controller: paused");
        vm.prank(pauseGuardian);
        controller.pause();
    }

    function testPause() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        controller.pause();
        bool paused = controller.paused();
        assertEq(paused, true);
    }

    function testCannotUnpauseNonPauseGuardian() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        controller.pause();
        vm.prank(address(123));
        vm.expectRevert("Controller: caller does not have the guardian role");
        controller.unpause();
    }

    function testCannotUnpauseWhenNopaused() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        vm.expectRevert("Controller: not paused");
        controller.unpause();
    }

    function testUnpause() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        controller.pause();
        vm.prank(pauseGuardian);
        controller.unpause();
        bool paused = controller.paused();
        assertEq(paused, false);
    }
}
