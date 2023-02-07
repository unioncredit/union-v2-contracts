// Note: if you are using this as a template
//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IMoneyMarketAdapter} from "../interfaces/IMoneyMarketAdapter.sol";
import {Controller} from "../Controller.sol";

contract PureTokenAdapter is Controller, IMoneyMarketAdapter {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev The address of the AssetManager
     */
    address public assetManager;

    /**
     * @dev Mapping of token address to floor balance
     */
    mapping(address => uint256) public override floorMap;

    /**
     * @dev Mapping of token address to ceiling balance
     */
    mapping(address => uint256) public override ceilingMap;

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __PureTokenAdapter_init(address admin, address _assetManager) public initializer {
        Controller.__Controller_init(admin);
        assetManager = _assetManager;
    }

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error TokenNotSupported();
    error SenderNotAssetManager();

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    /**
     * @dev Check supplied token address is supported
     */
    modifier checkTokenSupported(address tokenAddress) {
        if (!_supportsToken(tokenAddress)) revert TokenNotSupported();
        _;
    }

    /**
     * @dev Check sender is the asset manager
     */
    modifier onlyAssetManager() {
        if (msg.sender != assetManager) revert SenderNotAssetManager();
        _;
    }

    /* -------------------------------------------------------------------
      Setter Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Set the asset manager contract
     * @param _assetManager The AssetManager
     */
    function setAssetManager(address _assetManager) external onlyAdmin {
        assetManager = _assetManager;
    }

    /**
     * @dev Set the floor balance for this token.
     * When assets are deposited into adapters the floors are filled first
     * @param tokenAddress The Token address
     * @param floor Floor balance
     */
    function setFloor(address tokenAddress, uint256 floor) external onlyAdmin {
        floorMap[tokenAddress] = floor;
    }

    /**
     * @dev Set the ceiling balance for this token.
     * @dev The ceiling is the max balance we want to be managed by this adapter
     * @param tokenAddress The Token address
     * @param ceiling Ceiling balance
     */
    function setCeiling(address tokenAddress, uint256 ceiling) external onlyAdmin {
        ceilingMap[tokenAddress] = ceiling;
    }

    /* -------------------------------------------------------------------
      View Functions  
    ------------------------------------------------------------------- */

    /**
     * @dev Get the underlying market rate
     * @dev The PureAdapter doesn't have an underlying market so we return 0
     */
    function getRate(address) external pure override returns (uint256) {
        return 0;
    }

    /**
     * @dev Get total supply of this Contracts
     * @param tokenAddress The token to check supply for
     */
    function getSupply(address tokenAddress) external view override returns (uint256) {
        return _getSupply(tokenAddress);
    }

    /**
     * @dev Get total supply of this Contracts including any balance that has been
     * deposited into the underlying market. As the PureAdapter doesn't have an underlying
     * market this is the same as getSupply
     * @param tokenAddress The token to check supply for
     */
    function getSupplyView(address tokenAddress) external view override returns (uint256) {
        return _getSupply(tokenAddress);
    }

    /**
     * @dev Check if this token is supported
     * @param tokenAddress The token to check
     */
    function supportsToken(address tokenAddress) external view override returns (bool) {
        return _supportsToken(tokenAddress);
    }

    /* -------------------------------------------------------------------
      Core Functions  
    ------------------------------------------------------------------- */

    // solhint-disable-next-line no-empty-blocks
    function deposit(address tokenAddress) external view override checkTokenSupported(tokenAddress) returns (bool) {
        return true;
        // Don't have to do anything because AssetManager already transfered tokens here
    }

    /**
     * @dev Withdraw tokens from this adapter
     * @dev Only callable by the AssetManager
     * @param tokenAddress Token to withdraw
     * @param recipient Recieved by
     * @param tokenAmount Amount of tokens to withdraw
     */
    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 tokenAmount
    ) external override onlyAssetManager checkTokenSupported(tokenAddress) returns (bool) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.safeTransfer(recipient, tokenAmount);
        return true;
    }

    /**
     * @dev Withdraw entire balance of this token
     * @dev Only callable by AssetManager
     * @param tokenAddress Token to withdraw
     * @param recipient Recieved by
     */
    function withdrawAll(
        address tokenAddress,
        address recipient
    ) external override onlyAssetManager checkTokenSupported(tokenAddress) returns (bool) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.safeTransfer(recipient, token.balanceOf(address(this)));
        return true;
    }

    // solhint-disable-next-line no-empty-blocks
    function claimRewards(address tokenAddress, address recipient) external override onlyAdmin {
        // Pure manager has no rewards
    }

    /* -------------------------------------------------------------------
      Internal Functions 
    ------------------------------------------------------------------- */

    function _supportsToken(address tokenAddress) internal view returns (bool) {
        // Check if balanceOf reverst as a simple check to see if the token is ERC20 compatible
        // this is obviosly not a flawless check but it is good enough for the intention here
        return tokenAddress != address(0) && IERC20Upgradeable(tokenAddress).balanceOf(address(this)) >= 0;
    }

    function _getSupply(address tokenAddress) internal view returns (uint256) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        return token.balanceOf(address(this));
    }
}
