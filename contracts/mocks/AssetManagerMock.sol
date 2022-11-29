//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IAssetManager.sol";

contract AssetManagerMock is IAssetManager {
    struct Market {
        bool isSupported;
    }

    function setMarketRegistry(address marketRegistry) external {}

    function getPoolBalance(address tokenAddress) public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getLoanableAmount(address tokenAddress) public view returns (uint256) {
        return getPoolBalance(tokenAddress);
    }

    function totalSupply(address) public pure override returns (uint256) {
        return 0;
    }

    function totalSupplyView(address) public pure override returns (uint256) {
        return 0;
    }

    function isMarketSupported(address) public pure override returns (bool) {
        return false;
    }

    function deposit(address token, uint256 amount) external override returns (bool) {
        require(amount > 0, "AssetManager: amount can not be zero");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        return true;
    }

    function withdraw(
        address token,
        address account,
        uint256 amount
    ) external override returns (uint256) {
        uint256 remaining = amount;

        // If there are tokens in Asset Manager then transfer them on priority
        uint256 selfBalance = IERC20(token).balanceOf(address(this));
        if (selfBalance > 0) {
            uint256 withdrawAmount = selfBalance < remaining ? selfBalance : remaining;
            remaining -= withdrawAmount;
            IERC20(token).transfer(account, withdrawAmount);
        }
        return remaining;
    }

    function addToken(address) external override {}

    function removeToken(address) external override {}

    function addAdapter(address) external override {}

    function removeAdapter(address) external override {}

    function approveAllMarketsMax(address) external override {}

    function approveAllTokensMax(address) external override {}

    function setWithdrawSequence(uint256[] calldata) external override {}

    function rebalance(address, uint256[] calldata) external override {}

    function moneyMarketsCount() external pure override returns (uint256) {
        return 0;
    }

    function supportedTokensCount() external pure override returns (uint256) {
        return 0;
    }

    function getMoneyMarket(address, uint256) external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function debtWriteOff(address, uint256) external override {}
}
