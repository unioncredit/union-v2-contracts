//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IAssetManager.sol";

contract AssetManagerMock is IAssetManager {
    struct Market {
        bool isSupported;
    }

    function getPoolBalance(address) public view override returns (uint256) {
        return 0;
    }

    function getLoanableAmount(address) public view override returns (uint256) {
        return 0;
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

    function deposit(address, uint256) external override returns (bool) {
        return true;
    }

    function withdraw(
        address,
        address,
        uint256
    ) external override returns (bool) {
        return true;
    }

    function addToken(address) external override {}

    function removeToken(address) external override {}

    function claimTokens(address, address) external override {}

    function addAdapter(address) external override {}

    function removeAdapter(address) external override {}

    function approveAllMarketsMax(address) external override {}

    function approveAllTokensMax(address) external override {}

    function changeWithdrawSequence(uint256[] calldata) external override {}

    function rebalance(address, uint256[] calldata) external override {}

    function claimTokensFromAdapter(
        uint256,
        address,
        address
    ) external override {}

    function moneyMarketsCount() external view override returns (uint256) {
        return 0;
    }

    function supportedTokensCount() external view override returns (uint256) {
        return 0;
    }

    function getMoneyMarket(address, uint256) external view override returns (uint256, uint256) {
        return (0, 0);
    }

    function debtWriteOff(address, uint256) external override {}
}
