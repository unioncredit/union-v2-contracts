pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {MarketRegistry} from "union-v1.5-contracts/market/MarketRegistry.sol";

contract TestMarketRegistry is TestWrapper {
    MarketRegistry public marketRegistry;

    function setUp() public virtual {
        address marketRegistryLogic = address(new MarketRegistry());

        deployMocks();

        marketRegistry = MarketRegistry(
            deployProxy(marketRegistryLogic, abi.encodeWithSignature("__MarketRegistry_init()"))
        );
    }

    function testGetUToken(address token, address uToken) public {
        vm.assume(token != address(0) && uToken != address(0));
        marketRegistry.setUToken(token, uToken);
        assertEq(marketRegistry.uTokens(token), uToken);
    }

    function testGetUserManagers(address token, address userManager) public {
        vm.assume(token != address(0) && userManager != address(0));
        marketRegistry.setUserManager(token, userManager);
        assertEq(marketRegistry.userManagers(token), userManager);
    }

    function testCannotAddUserMangerNonAdmin() public {
        vm.expectRevert("Controller: not admin");
        vm.prank(address(1));
        marketRegistry.setUserManager(address(0), address(0));
    }

    function testCannotAddUTokenNonAdmin() public {
        vm.expectRevert("Controller: not admin");
        vm.prank(address(1));
        marketRegistry.setUToken(address(0), address(0));
    }
}
