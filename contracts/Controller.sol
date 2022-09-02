//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Controller component
 * @dev For easy access to any core components
 */
abstract contract Controller is Initializable, UUPSUpgradeable {
    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev The address of the admin
     */
    address public admin;

    /**
     * @dev The address of the pending admin
     */
    address public pendingAdmin;

    /**
     * @dev Is the contract paused
     */
    bool private _paused;

    /**
     * @dev The address of the pause guardian
     */
    address public pauseGuardian;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error Paused();
    error NotPaused();
    error SenderNotAdmin();
    error SenderNotGuardian();
    error SenderNotPendingAdmin();

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event LogPaused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event LogUnpaused(address account);

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        if (_paused) revert Paused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        if (!_paused) revert NotPaused();
        _;
    }

    modifier onlyAdmin() {
        if (admin != msg.sender) revert SenderNotAdmin();
        _;
    }

    modifier onlyGuardian() {
        if (pauseGuardian != msg.sender) revert SenderNotGuardian();
        _;
    }

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    //When using minimal deploy, do not call initialize directly during deploy, because msg.sender is the proxyFactory address, and you need to call it manually
    function __Controller_init(address admin_) public initializer {
        _paused = false;
        admin = admin_;
        __UUPSUpgradeable_init();
        pauseGuardian = admin_;
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    function _authorizeUpgrade(address) internal view override onlyAdmin {}

    /**
     * @dev Check if the address provided is the admin
     * @param account Account address
     */
    function isAdmin(address account) public view returns (bool) {
        return account == admin;
    }

    /**
     * @dev set new admin account
     * @param account Account address
     */
    function setPendingAdmin(address account) public onlyAdmin {
        pendingAdmin = account;
    }

    function acceptAdmin() public {
        if (pendingAdmin != msg.sender) revert SenderNotPendingAdmin();
        admin = pendingAdmin;
    }

    /**
     * @dev Set pauseGuardian account
     * @param account Account address
     */
    function setGuardian(address account) external onlyAdmin {
        pauseGuardian = account;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() external onlyGuardian whenNotPaused {
        _paused = true;
        emit LogPaused(msg.sender);
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() external onlyGuardian whenPaused {
        _paused = false;
        emit LogUnpaused(msg.sender);
    }

    uint256[50] private ______gap;
}
