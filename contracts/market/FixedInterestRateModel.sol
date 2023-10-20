//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

/**
 * @author Union
 * @dev The interest rate model used by UTokens
 */
contract FixedInterestRateModel is Ownable, IInterestRateModel {
    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */
    /**
     * @dev Maximum borrow rate that can ever be applied (0.005% / 12 second)
     */
    uint256 public constant BORROW_RATE_MAX_MANTISSA = 4_166_666_666_667; // 0.005e16 / 12

    /**
     * @dev IInterest rate per second
     */
    uint256 public interestRatePerSecond;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error ReserveFactorExceeded();
    error BorrowRateExceeded();

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Update interest parameters event
     *  @param interestRate New interest rate, 1e18 = 100%
     */
    event LogNewInterestParams(uint256 interestRate);

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    constructor(uint256 interestRatePerSecond_) {
        interestRatePerSecond = interestRatePerSecond_;

        emit LogNewInterestParams(interestRatePerSecond_);
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Get borrow rate per second
     */
    function getBorrowRate() public view override returns (uint256) {
        return interestRatePerSecond;
    }

    /**
     * @dev Get supply rate for given reserve factor
     * @dev If reserve factor is 100% interest accrued to the reserves
     * @dev If reserves factor is 0 interest accrued to uDAI minters
     * @param reserveFactorMantissa The reserve factor (scaled)
     */
    function getSupplyRate(uint256 reserveFactorMantissa) public view override returns (uint256) {
        if (reserveFactorMantissa > 1e18) revert ReserveFactorExceeded();
        uint256 ratio = uint256(1e18) - reserveFactorMantissa;
        return (interestRatePerSecond * ratio) / 1e18;
    }

    /* -------------------------------------------------------------------
      Setter Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Set new interest rate per second
     * @dev Interest rate per second must be less than the max rate
     * @param _interestRatePerSecond Interest rate
     */
    function setInterestRate(uint256 _interestRatePerSecond) external override onlyOwner {
        if (_interestRatePerSecond > BORROW_RATE_MAX_MANTISSA) revert BorrowRateExceeded();
        interestRatePerSecond = _interestRatePerSecond;

        emit LogNewInterestParams(_interestRatePerSecond);
    }
}
