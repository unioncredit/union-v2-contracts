//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Controller} from "../Controller.sol";
import {IMarketRegistry} from "../interfaces/IMarketRegistry.sol";

/**
 * @title MarketRegistry Contract
 * @author Union
 * @dev Register uToken and UserManager contracts to their tokens
 */
contract MarketRegistry is Controller, IMarketRegistry {
    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @notice Token address mapped to userManager
     * @dev Assumption there will only ever be one UserManager per token
     */
    mapping(address => address) public userManagers;

    /**
     * @notice Token address mapped to uToken
     * @dev Assumption there will only ever be one UToken per token
     */
    mapping(address => address) public uTokens;

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

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    /**
     *  @dev Initialization function
     */
    function __MarketRegistry_init(address admin) public initializer {
        Controller.__Controller_init(admin);
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    function hasUToken(address token) external view returns (bool) {
        return uTokens[token] != address(0);
    }

    function hasUserManager(address token) external view returns (bool) {
        return userManagers[token] != address(0);
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Register a new UToken contract
     * @param token The underlying token e.g DAI
     * @param uToken the address of the uToken contract
     */
    function setUToken(address token, address uToken) external onlyAdmin {
        uTokens[token] = uToken;
        emit LogAddUToken(token, uToken);
    }

    /**
     * @dev Register a new UToken contract
     * @param token The underlying token e.g DAI
     * @param userManager the address of the UserManager contract
     */
    function setUserManager(address token, address userManager) external onlyAdmin {
        userManagers[token] = userManager;
        emit LogAddUserManager(token, userManager);
    }
}
