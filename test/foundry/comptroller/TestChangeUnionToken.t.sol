pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestChangeUnionToken is TestComptrollerBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotChangeUnionTokenNotAdmin(address newAddress) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        comptroller.changeUnionToken(newAddress);
    }

    function testChangeUnionToken() public {
        address newAddress = address(10);
        vm.startPrank(ADMIN);
        comptroller.changeUnionToken(newAddress);
        assertEq(address(comptroller.unionToken()), newAddress);
        vm.stopPrank();
    }

    function testCannotRemoveOpUnionNotAdmin(address oldToken) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        comptroller.removeOpUnion(oldToken, ADMIN);
    }

    function testRemoveOpUnion() public {
        unionTokenMock.mint(address(comptroller), 1 ether);
        uint bal = unionTokenMock.balanceOf(address(comptroller));
        assertEq(bal, 1 ether);
        vm.startPrank(ADMIN);
        comptroller.removeOpUnion(address(11), address(unionTokenMock));
        bal = unionTokenMock.balanceOf(address(11));
        assertEq(bal, 1 ether);
        vm.stopPrank();
    }
}
