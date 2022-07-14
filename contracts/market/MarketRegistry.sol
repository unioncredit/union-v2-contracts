//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Controller} from "../Controller.sol";

/**
 * @title MarketRegistry Contract
 * @author Union
 * @dev Register uToken and UserManager contracts to their tokens
 */
contract MarketRegistry is Controller {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct Market {
        address uToken;
        address userManager;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    EnumerableSet.AddressSet private uTokenList;

    EnumerableSet.AddressSet private userManagerList;

    /**
     * @dev Token address mapped to the Market
     */
    mapping(address => Market) public tokens;

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     * @dev New UToken contract registered
     * @param tokenAddress The address of the underlying token
     * @param contractAddress The contract address
     */
    event LogAddUToken(address indexed tokenAddress, address contractAddress);

    /**
     * @dev New UserManager contract registered
     * @param tokenAddress The address of the underlying token
     * @param contractAddress The contract address
     */
    event LogAddUserManager(address indexed tokenAddress, address contractAddress);

    /**
     * @dev Market deleted
     * @param tokenAddress The address of the underlying token
     */
    event LogDeleteMarket(address indexed tokenAddress);

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    /**
     *  @dev Initialization function
     */
    function __MarketRegistry_init() public initializer {
        Controller.__Controller_init(msg.sender);
    }

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    modifier newUToken(address token) {
        require(tokens[token].uToken == address(0), "MarketRegistry: uToken already added");
        _;
    }

    modifier newUserManager(address token) {
        require(tokens[token].userManager == address(0), "MarketRegistry: userManager already added");
        _;
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Get all the registered UToken contracts
     *  @return uToken addresses
     */
    function getUTokens() public view returns (address[] memory) {
        return uTokenList.values();
    }

    /**
     *  @dev Get all the registered UserManager contracts
     *  @return UserManager addresses
     */
    function getUserManagers() public view returns (address[] memory) {
        return userManagerList.values();
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Register a new UToken contract
     * @param token The underlying token e.g DAI
     * @param uToken the address of the uToken contract
     */
    function addUToken(address token, address uToken) public newUToken(token) onlyAdmin {
        require(token != address(0) && uToken != address(0), "MarketRegistry: token and uToken can not be zero");
        uTokenList.add(uToken);
        tokens[token].uToken = uToken;

        emit LogAddUToken(token, uToken);
    }

    /**
     * @dev Register a new UToken contract
     * @param token The underlying token e.g DAI
     * @param userManager the address of the UserManager contract
     */
    function addUserManager(address token, address userManager) public newUserManager(token) onlyAdmin {
        require(
            token != address(0) && userManager != address(0),
            "MarketRegistry: token and userManager can not be zero"
        );
        userManagerList.add(userManager);
        tokens[token].userManager = userManager;

        emit LogAddUserManager(token, userManager);
    }

    /**
     * @dev Remove a market
     * @param token The underlying token e.g DAI
     */
    function deleteMarket(address token) public onlyAdmin {
        uTokenList.remove(tokens[token].uToken);
        userManagerList.remove(tokens[token].userManager);

        delete tokens[token].uToken;
        delete tokens[token].userManager;

        emit LogDeleteMarket(token);
    }
}
