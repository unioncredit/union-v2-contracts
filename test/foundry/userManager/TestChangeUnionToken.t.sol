pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestChangeUnionToken is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
        comptrollerMock.setUserManager(address(userManager));
    }

    function testCannotChangeUnionTokenNotAdmin(address newAddress) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.changeUnionToken(newAddress);
    }

    function testChangeUnionToken() public {
        address newAddress = address(10);
        vm.startPrank(ADMIN);
        userManager.changeUnionToken(newAddress);
        assertEq(userManager.unionToken(), newAddress);
        vm.stopPrank();
    }
}
