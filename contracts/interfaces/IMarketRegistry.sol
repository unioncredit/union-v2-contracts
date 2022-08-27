//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title MarketRegistry Interface
 * @dev Registering and managing all the lending markets.
 */
interface IMarketRegistry {
    function userManagers(address token) external view returns (address);

    function uTokens(address token) external view returns (address);

    function hasUToken(address token) external view returns (bool);

    function hasUserManager(address token) external view returns (bool);

    function setUToken(address token, address uToken) external;

    function setUserManager(address token, address userManager) external;
}
