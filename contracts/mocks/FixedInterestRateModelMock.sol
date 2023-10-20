//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interfaces/IInterestRateModel.sol";

contract FixedInterestRateModelMock is IInterestRateModel {
    uint256 public interestRatePerSecond;

    constructor(uint256 interestRatePerBlock_) {
        interestRatePerSecond = interestRatePerBlock_;
    }

    function getBorrowRate() public view returns (uint256) {
        return interestRatePerSecond;
    }

    function getSupplyRate(uint256 reserveFactorMantissa) public view returns (uint256) {
        uint256 ratio = uint256(1e18) - reserveFactorMantissa;
        return (interestRatePerSecond * ratio) / 1e18;
    }

    function setInterestRate(uint256 interestRatePerBlock_) external {
        interestRatePerSecond = interestRatePerBlock_;
    }
}
