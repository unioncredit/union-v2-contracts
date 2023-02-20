pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract FakeControllerOld is Controller {
    uint256 public temp;

    function __FakeController_init(address admin) external initializer {
        Controller.__Controller_init(admin);
        temp = 1;
    }
}

contract FakeControllerNew is Controller {
    uint256 public temp;

    function __FakeController_init(address admin) external initializer {
        Controller.__Controller_init(admin);
    }

    function setTemp(uint256 _temp) external {
        temp = _temp;
    }
}

contract TestController is TestWrapper {
    FakeControllerNew public controller;
    address public constant ADMIN = address(1);

    function setUp() public virtual {
        address controllerLogic = address(new FakeControllerOld());
        controller = FakeControllerNew(
            deployProxy(controllerLogic, abi.encodeWithSignature("__FakeController_init(address)", [ADMIN]))
        );
    }

    function testIsAdmin() public {
        assertEq(controller.isAdmin(address(1)), true);
        assertEq(controller.isAdmin(address(2)), false);
    }

    function testSetPendingAdmin(address account) public {
        vm.assume(account != address(0));
        vm.prank(ADMIN);
        controller.setPendingAdmin(account);
        address pendingAdmin = controller.pendingAdmin();
        assertEq(pendingAdmin, account);
    }

    function testCannotAcceptAdminNonPendingAdminr() public {
        vm.expectRevert(Controller.SenderNotPendingAdmin.selector);
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
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        controller.setGuardian(account);
    }

    function testSetGuardian(address account) public {
        vm.prank(ADMIN);
        controller.setGuardian(account);
        address pauseGuardian = controller.pauseGuardian();
        assertEq(pauseGuardian, account);
    }

    function testCannotPauseNonPauseGuardian() public {
        vm.expectRevert(Controller.SenderNotGuardian.selector);
        controller.pause();
    }

    function testCannotPauseWhenPaused() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        controller.pause();
        vm.expectRevert(Controller.Paused.selector);
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
        vm.expectRevert(Controller.SenderNotGuardian.selector);
        controller.unpause();
    }

    function testCannotUnpauseWhenNopaused() public {
        address pauseGuardian = controller.pauseGuardian();
        vm.prank(pauseGuardian);
        vm.expectRevert(Controller.NotPaused.selector);
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

    function testUpgrading(uint256 amount) public {
        vm.assume(amount != 1);
        address newControllerLogic = address(new FakeControllerNew());
        vm.prank(ADMIN);
        controller.upgradeTo(newControllerLogic);
        assertEq(controller.temp(), 1);
        controller.setTemp(amount);
        assertEq(controller.temp(), amount);
    }
}
