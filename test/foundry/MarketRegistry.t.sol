pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {MarketRegistry} from "union-v1.5-contracts/market/MarketRegistry.sol";

contract TestUserManagerBase is TestWrapper {
    MarketRegistry public marketRegistry;

    function setUp() public virtual {
        address marketRegistryLogic = address(new MarketRegistry());

        deployMocks();

        marketRegistry = MarketRegistry(
            deployProxy(marketRegistryLogic, abi.encodeWithSignature("__MarketRegistry_init()"))
        );
    }

    function testGetUTokens(address token, address uToken) public {
        vm.assume(token != address(0) && uToken != address(0));
        marketRegistry.addUToken(token, uToken);
        address[] memory addresses = marketRegistry.getUTokens();
        assertEq(addresses[0], uToken);
    }

    function testGetUserManagers(address token, address userManager) public {
        vm.assume(token != address(0) && userManager != address(0));
        marketRegistry.addUserManager(token, userManager);
        address[] memory addresses = marketRegistry.getUserManagers();
        assertEq(addresses[0], userManager);
    }

    function testAddUToken(address token, address uToken) public {
        vm.assume(token != address(0) && uToken != address(0));
        marketRegistry.addUToken(token, uToken);
        (address registeredUToken, ) = marketRegistry.tokens(token);
        assertEq(registeredUToken, uToken);
    }

    function testCannotAddUTokenZeroAddress(address uToken) public {
        vm.expectRevert("MarketRegistry: token and uToken can not be zero");
        marketRegistry.addUToken(address(0), uToken);
    }

    function testCannotAddUTokenExisting(address token, address uToken) public {
        vm.assume(token != address(0) && uToken != address(0));
        marketRegistry.addUToken(token, uToken);
        vm.expectRevert("MarketRegistry: uToken already added");
        marketRegistry.addUToken(token, uToken);
    }

    function testAddUserManager(address token, address userManager) public {
        vm.assume(token != address(0) && userManager != address(0));
        marketRegistry.addUserManager(token, userManager);
        (, address registeredUserManager) = marketRegistry.tokens(token);
        assertEq(registeredUserManager, userManager);
    }

    function testCannotAddUserManagerZeroAddress(address userManager) public {
        vm.expectRevert("MarketRegistry: token and userManager can not be zero");
        marketRegistry.addUserManager(address(0), userManager);
    }

    function testCannotAddUserManagerExisting(address token, address userManager) public {
        vm.assume(token != address(0) && userManager != address(0));
        marketRegistry.addUserManager(token, userManager);
        vm.expectRevert("MarketRegistry: userManager already added");
        marketRegistry.addUserManager(token, userManager);
    }

    function testCannotDeleteMarketNonAdmin() public {
        vm.startPrank(address(1));
        vm.expectRevert("Controller: not admin");
        marketRegistry.deleteMarket(address(0));
        vm.stopPrank();
    }

    function testDeleteMarket(
        address token,
        address userManager,
        address uToken
    ) public {
        vm.assume(token != address(0) && userManager != address(0) && uToken != address(0));
        marketRegistry.addUserManager(token, userManager);
        marketRegistry.addUToken(token, uToken);

        (address registeredUToken, address registeredUserManager) = marketRegistry.tokens(token);
        assertEq(registeredUserManager, userManager);
        assertEq(registeredUToken, uToken);

        marketRegistry.deleteMarket(token);

        (address ru, address rum) = marketRegistry.tokens(token);
        assertEq(ru, address(0));
        assertEq(rum, address(0));
    }
}
