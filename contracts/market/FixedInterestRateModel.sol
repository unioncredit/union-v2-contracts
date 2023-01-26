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
     * @dev Maximum borrow rate that can ever be applied (0.005% / block)
     */
    uint256 public constant BORROW_RATE_MAX_MANTISSA = 0.005e16;

    /**
     * @dev IInterest rate per block
     */
    uint256 public interestRatePerBlock;

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

    constructor(uint256 interestRatePerBlock_) {
        interestRatePerBlock = interestRatePerBlock_;

        emit LogNewInterestParams(interestRatePerBlock_);
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Get borrow rate per block
     */
    function getBorrowRate() public view override returns (uint256) {
        return interestRatePerBlock;
    }

    /**
     * @dev Get supply rate for given reserve factor
     * @dev If reserve factor is 100% interest acres to the reserves
     * @dev If reserves factor is 0 interest acres to uDAI minters
     * @param reserveFactorMantissa The reserve factor (scaled)
     */
    function getSupplyRate(uint256 reserveFactorMantissa) public view override returns (uint256) {
        if (reserveFactorMantissa > 1e18) revert ReserveFactorExceeded();
        uint256 ratio = uint256(1e18) - reserveFactorMantissa;
        return (interestRatePerBlock * ratio) / 1e18;
    }

    /* -------------------------------------------------------------------
      Setter Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Set new interest rate per block
     * @dev Interest rate per block must be less than the max rate 0.005% / block
     * @param _interestRatePerBlock Interest rate
     */
    function setInterestRate(uint256 _interestRatePerBlock) external override onlyOwner {
        if (_interestRatePerBlock > BORROW_RATE_MAX_MANTISSA) revert BorrowRateExceeded();
        interestRatePerBlock = _interestRatePerBlock;

        emit LogNewInterestParams(_interestRatePerBlock);
    }
}
