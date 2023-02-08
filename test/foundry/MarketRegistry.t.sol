pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {MarketRegistry} from "union-v2-contracts/market/MarketRegistry.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestMarketRegistry is TestWrapper {
    MarketRegistry public marketRegistry;

    address public constant ADMIN = address(0);

    function setUp() public virtual {
        address marketRegistryLogic = address(new MarketRegistry());

        deployMocks();

        marketRegistry = MarketRegistry(
            deployProxy(marketRegistryLogic, abi.encodeWithSignature("__MarketRegistry_init(address)", [ADMIN]))
        );
    }

    function testGetUToken(address token, address uToken) public {
        vm.assume(token != address(0) && uToken != address(0));
        vm.prank(ADMIN);
        marketRegistry.setUToken(token, uToken);
        assertEq(marketRegistry.uTokens(token), uToken);
    }

    function testGetUserManagers(address token, address userManager) public {
        vm.assume(token != address(0) && userManager != address(0));
        vm.prank(ADMIN);
        marketRegistry.setUserManager(token, userManager);
        assertEq(marketRegistry.userManagers(token), userManager);
    }

    function testCannotAddUserMangerNonAdmin() public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        vm.prank(address(1));
        marketRegistry.setUserManager(address(0), address(0));
    }

    function testCannotAddUTokenNonAdmin() public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        vm.prank(address(1));
        marketRegistry.setUToken(address(0), address(0));
    }

    function testHasUToken(address token, address uToken) public {
        vm.assume(token != address(123) && token != address(0) && uToken != address(0));
        vm.prank(ADMIN);
        marketRegistry.setUToken(token, uToken);
        assert(marketRegistry.hasUToken(token));
        assert(!marketRegistry.hasUToken(address(123)));
    }

    function testHasUserManager(address token, address userManager) public {
        vm.assume(token != address(123) && token != address(0) && userManager != address(0));
        vm.prank(ADMIN);
        marketRegistry.setUserManager(token, userManager);
        assert(marketRegistry.hasUserManager(token));
        assert(!marketRegistry.hasUserManager(address(123)));
    }
}
