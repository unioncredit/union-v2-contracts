//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUToken} from "../interfaces/IUToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UTokenMock is ERC20("uTokenMock", "UMOCK"), IUToken {
    function setAssetManager(address) external {}

    function setUserManager(address) external {}

    function exchangeRateStored() external pure returns (uint256) {
        return 0;
    }

    function exchangeRateCurrent() external pure returns (uint256) {
        return 0;
    }

    function overdueBlocks() external pure override returns (uint256) {
        return 0;
    }

    function getRemainingDebtCeiling() external pure override returns (uint256) {
        return 0;
    }

    function getBorrowed(address) external pure override returns (uint256) {
        return 0;
    }

    function getLastRepay(address) external pure override returns (uint256) {
        return 0;
    }

    function checkIsOverdue(address) external pure override returns (bool) {
        return false;
    }

    function borrowRatePerBlock() external pure override returns (uint256) {
        return 0;
    }

    function calculatingFee(uint256) external pure returns (uint256) {
        return 0;
    }

    function calculatingInterest(address) external pure override returns (uint256) {
        return 0;
    }

    function borrowBalanceView(address) external pure override returns (uint256) {
        return 0;
    }

    function setOriginationFee(uint256) external override {}

    function setDebtCeiling(uint256) external override {}

    function setMaxBorrow(uint256) external override {}

    function setMinBorrow(uint256) external override {}

    function setOverdueBlocks(uint256) external override {}

    function setInterestRateModel(address) external override {}

    function setReserveFactor(uint256) external override {}

    function supplyRatePerBlock() external pure override returns (uint256) {
        return 1;
    }

    function accrueInterest() external pure override returns (bool) {
        return true;
    }

    function balanceOfUnderlying(address) external pure override returns (uint256) {
        return 0;
    }

    function mint(uint256) external override {}

    function redeem(uint256, uint256) external override {}

    function addReserves(uint256) external override {}

    function removeReserves(address, uint256) external override {}

    function borrow(address, uint256) external override {}

    function repayBorrow(address, uint256) external override {}

    function debtWriteOff(address, uint256) external override {}
}
