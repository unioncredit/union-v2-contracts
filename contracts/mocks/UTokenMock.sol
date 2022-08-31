//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUToken} from "../interfaces/IUToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UTokenMock is ERC20("uTokenMock", "UMOCK"), IUToken {
    function overdueBlocks() external view override returns (uint256) {
        return 0;
    }

    function getRemainingDebtCeiling() external view override returns (uint256) {
        return 0;
    }

    function getBorrowed(address account) external view override returns (uint256) {
        return 0;
    }

    function getLastRepay(address account) external view override returns (uint256) {
        return 0;
    }

    function getInterestIndex(address account) external view override returns (uint256) {
        return 0;
    }

    function checkIsOverdue(address account) external view override returns (bool) {
        return false;
    }

    function borrowRatePerBlock() external view override returns (uint256) {
        return 0;
    }

    function calculatingFee(uint256) external view override returns (uint256) {
        return 0;
    }

    function calculatingInterest(address) external view override returns (uint256) {
        return 0;
    }

    function borrowBalanceView(address) external view override returns (uint256) {
        return 0;
    }

    function setOriginationFee(uint256) external override {}

    function setDebtCeiling(uint256) external override {}

    function setMaxBorrow(uint256) external override {}

    function setMinBorrow(uint256) external override {}

    function setOverdueBlocks(uint256) external override {}

    function setInterestRateModel(address) external override {}

    function setReserveFactor(uint256) external override {}

    function supplyRatePerBlock() external override returns (uint256) {
        return 1;
    }

    function accrueInterest() external override returns (bool) {
        return true;
    }

    function balanceOfUnderlying(address) external override returns (uint256) {
        return 0;
    }

    function mint(uint256) external override {}

    function redeem(uint256) external override {}

    function redeemUnderlying(uint256) external override {}

    function addReserves(uint256) external override {}

    function removeReserves(address, uint256) external override {}

    function borrow(address, uint256) external override {}

    function repayBorrow(address, uint256) external override {}

    function debtWriteOff(address, uint256) external override {}
}
