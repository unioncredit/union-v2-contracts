//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/IMoneyMarketAdapter.sol";

contract CompoundAdapterMock is Initializable, IMoneyMarketAdapter {
    bool public isSupport;
    mapping(address => uint256) public floorMap;
    mapping(address => uint256) public ceilingMap;

    function __CompoundAdapterMock_init() public initializer {}

    function claimRewards(address tokenAddress, address recipient) external {}

    function getRate(address tokenAddress) external view returns (uint256) {}

    function setAssetManager(address) external {}

    function setSupport() external {
        isSupport = !isSupport;
    }

    function setFloor(address tokenAddress, uint256 floor) external {
        floorMap[tokenAddress] = floor;
    }

    function setCeiling(address tokenAddress, uint256 ceiling) external {
        ceilingMap[tokenAddress] = ceiling;
    }

    function supportsToken(address) external view returns (bool) {
        return isSupport;
    }

    function getSupplyView(address tokenAddress) external view returns (uint256) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        return token.balanceOf(address(this));
    }

    function getSupply(address tokenAddress) external view returns (uint256) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        return token.balanceOf(address(this));
    }

    function deposit(address) external pure returns (bool) {
        return true;
    }

    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 tokenAmount
    ) external returns (bool) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.transfer(recipient, tokenAmount);
        return true;
    }

    function withdrawAll(address tokenAddress, address recipient) external returns (bool) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        token.transfer(recipient, token.balanceOf(address(this)));
        return true;
    }
}
