//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../Controller.sol";

/**
 * @title MarketRegistry Contract
 * @dev Registering and managing all the lending markets.
 */
contract MarketRegistry is Controller {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Market {
        address uToken;
        address userManager;
    }

    EnumerableSet.AddressSet private uTokenList;
    EnumerableSet.AddressSet private userManagerList;
    mapping(address => Market) public tokens;

    event LogAddUToken(address indexed tokenAddress, address contractAddress);

    event LogAddUserManager(address indexed tokenAddress, address contractAddress);

    modifier newToken(address token) {
        require(tokens[token].uToken == address(0), "MarketRegistry: has already exist this uToken");
        _;
    }

    modifier newUserManager(address token) {
        require(tokens[token].userManager == address(0), "MarketRegistry: has already exist this userManager");
        _;
    }

    /**
     *  @dev Initialization function
     */
    function __MarketRegistry_init() public initializer {
        Controller.__Controller_init(msg.sender);
    }

    /**
     *  @dev Retrieves the value of the state variable `uTokenList`
     *  @return Stored uToken address
     */
    function getUTokens() public view returns (address[] memory) {
        return uTokenList.values();
    }

    function getUserManagers() public view returns (address[] memory) {
        return userManagerList.values();
    }

    function addUToken(address token, address uToken) public newToken(token) onlyAdmin {
        require(token != address(0) && uToken != address(0), "MarketRegistry: token and uToken can not be zero");
        uTokenList.add(uToken);
        tokens[token].uToken = uToken;
        emit LogAddUToken(token, uToken);
    }

    function addUserManager(address token, address userManager) public newUserManager(token) onlyAdmin {
        require(
            token != address(0) && userManager != address(0),
            "MarketRegistry: token and userManager can not be zero"
        );
        userManagerList.add(userManager);
        tokens[token].userManager = userManager;
        emit LogAddUserManager(token, userManager);
    }

    function deleteMarket(address token) public onlyAdmin {
        uTokenList.remove(tokens[token].uToken);
        userManagerList.remove(tokens[token].userManager);
        delete tokens[token].uToken;
        delete tokens[token].userManager;
    }
}
