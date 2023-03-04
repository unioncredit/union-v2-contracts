pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {OpOwner, IOvmL2CrossDomainMessenger} from "union-v2-contracts/OpOwner.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestOpOwner is TestWrapper {
    OpOwner public opOwner;

    address public constant ADMIN = address(1);
    address public constant OWNER = address(2);
    IOvmL2CrossDomainMessenger public constant ovmL2CrossDomainMessenger = IOvmL2CrossDomainMessenger(address(3));

    function setUp() public virtual {
        opOwner = new OpOwner(ADMIN, OWNER, ovmL2CrossDomainMessenger);
    }

    function testCannotSetPendingOwnerNonOwner() public {
        vm.prank(address(4));
        vm.expectRevert();
        opOwner.setPendingOwner(address(5));
    }

    function testCannotSetPendingAdminNonAdmin() public {
        vm.prank(address(4));
        vm.expectRevert();
        opOwner.setPendingAdmin(address(5));
    }

    function testCannotCallExecuteNonAdminOrOwner() public {
        vm.prank(address(4));
        vm.expectRevert();
        opOwner.execute(address(5), 0, bytes("0x0"));
    }

    function testCannotSetPendingOwnerWithZero() public {
        vm.mockCall(
            address(ovmL2CrossDomainMessenger),
            abi.encodeWithSelector(IOvmL2CrossDomainMessenger.xDomainMessageSender.selector),
            abi.encode(OWNER)
        );
        vm.prank(address(ovmL2CrossDomainMessenger));
        vm.expectRevert(OpOwner.AddressNotZero.selector);
        opOwner.setPendingOwner(address(0));
        vm.clearMockedCalls();
    }

    function testCannotSetPendingAdminWithZero() public {
        vm.prank(ADMIN);
        vm.expectRevert(OpOwner.AddressNotZero.selector);
        opOwner.setPendingAdmin(address(0));
    }

    function testAcceptOwner() public {
        vm.mockCall(
            address(ovmL2CrossDomainMessenger),
            abi.encodeWithSelector(IOvmL2CrossDomainMessenger.xDomainMessageSender.selector),
            abi.encode(OWNER)
        );
        vm.prank(address(ovmL2CrossDomainMessenger));
        opOwner.setPendingOwner(address(4));
        assertEq(address(4), opOwner.pendingOwner());
        vm.clearMockedCalls();
        vm.expectRevert(OpOwner.SenderNotPendingOwner.selector);
        opOwner.acceptOwner();

        vm.prank(address(4));
        opOwner.acceptOwner();
        assertEq(address(4), opOwner.owner());
    }

    function testAcceptAdmin() public {
        vm.prank(ADMIN);
        opOwner.setPendingAdmin(address(4));
        assertEq(address(4), opOwner.pendingAdmin());

        vm.expectRevert(OpOwner.SenderNotPendingAdmin.selector);
        opOwner.acceptAdmin();

        vm.prank(address(4));
        opOwner.acceptAdmin();
        assertEq(address(4), opOwner.admin());
    }

    function testCallExecute() public {
        vm.prank(ADMIN);
        vm.expectRevert("underlying transaction reverted");
        opOwner.execute(address(5), 0, bytes("0x0"));
    }
}
