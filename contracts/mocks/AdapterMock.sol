// Note: if you are using this as a template
//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IMoneyMarketAdapter} from "../interfaces/IMoneyMarketAdapter.sol";

contract AdapterMock is IMoneyMarketAdapter {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public assetManager;

    uint256 public rate;

    bool public toRevert;

    /**
     * @dev Mapping of token address to floor balance
     */
    mapping(address => uint256) public override floorMap;

    /**
     * @dev Mapping of token address to ceiling balance
     */
    mapping(address => uint256) public override ceilingMap;

    function setRevert() external {
        toRevert = !toRevert;
    }

    function setAssetManager(address _assetManager) external {
        assetManager = _assetManager;
    }

    function setFloor(address tokenAddress, uint256 floor) external {
        floorMap[tokenAddress] = floor;
    }

    function setCeiling(address tokenAddress, uint256 ceiling) external {
        ceilingMap[tokenAddress] = ceiling;
    }

    function setRate(uint256 _rate) external {
        rate = _rate;
    }

    function getRate(address) external view override returns (uint256) {
        return rate;
    }

    function getSupply(address tokenAddress) external view override returns (uint256) {
        return _getSupply(tokenAddress);
    }

    function getSupplyView(address tokenAddress) external view override returns (uint256) {
        return _getSupply(tokenAddress);
    }

    function supportsToken(address) external pure override returns (bool) {
        return true;
    }

    function deposit(address tokenAddress) external override returns (bool) {
        if (toRevert) {
            IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
            uint256 tokenAmount = token.balanceOf(address(this));
            token.safeTransfer(msg.sender, tokenAmount);
            return false;
        }
        return true;
    }

    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 tokenAmount
    ) external override returns (bool) {
        if (toRevert) return false;
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.safeTransfer(recipient, tokenAmount);
        return true;
    }

    function withdrawAll(address tokenAddress, address recipient) external override returns (bool) {
        if (toRevert) return false;
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.safeTransfer(recipient, token.balanceOf(address(this)));
        return true;
    }

    function claimRewards(address, address) external override {}

    function _getSupply(address tokenAddress) internal view returns (uint256) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        return token.balanceOf(address(this));
    }
}
