//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma abicoder v1;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IInterestRateModel.sol";

contract FixedInterestRateModel is Ownable, IInterestRateModel {
    uint256 public constant BORROW_RATE_MAX_MANTISSA = 0.005e16; //Maximum borrow rate that can ever be applied (.005% / block)
    bool public constant override isInterestRateModel = true;
    uint256 public interestRatePerBlock;

    /**
     *  @dev Update interest parameters event
     *  @param interestRate New interest rate, 1e18 = 100%
     */
    event LogNewInterestParams(uint256 interestRate);

    constructor(uint256 interestRatePerBlock_) {
        interestRatePerBlock = interestRatePerBlock_;

        emit LogNewInterestParams(interestRatePerBlock_);
    }

    function getBorrowRate() public view override returns (uint256) {
        return interestRatePerBlock;
    }

    function getSupplyRate(uint256 reserveFactorMantissa) public view override returns (uint256) {
        require(reserveFactorMantissa <= 1e18, "reserveFactorMantissa error");
        uint256 ratio = uint256(1e18) - reserveFactorMantissa;
        return (interestRatePerBlock * ratio) / 1e18;
    }

    function setInterestRate(uint256 interestRatePerBlock_) external override onlyOwner {
        require(interestRatePerBlock_ <= BORROW_RATE_MAX_MANTISSA, "borrow rate is absurdly high");
        interestRatePerBlock = interestRatePerBlock_;
        emit LogNewInterestParams(interestRatePerBlock_);
    }
}
