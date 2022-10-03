pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {FixedInterestRateModel} from "union-v2-contracts/market/FixedInterestRateModel.sol";

contract TestFixedInterestRateModel is TestWrapper {
    FixedInterestRateModel public fixedInterestRateModel;

    uint256 interestRatePerBlock = 123;

    function setUp() public virtual {
        fixedInterestRateModel = new FixedInterestRateModel(interestRatePerBlock);
    }

    function testGetBorrowRate() public {
        assertEq(fixedInterestRateModel.interestRatePerBlock(), interestRatePerBlock);
        assertEq(fixedInterestRateModel.getBorrowRate(), interestRatePerBlock);
    }

    function testGetSupplyRate(uint256 reserveFactorMantissa) public {
        vm.assume(reserveFactorMantissa <= 1e18);
        uint256 ratio = uint256(1e18) - reserveFactorMantissa;
        uint256 expected = (interestRatePerBlock * ratio) / 1e18;
        assertEq(expected, fixedInterestRateModel.getSupplyRate(reserveFactorMantissa));
    }

    function testSetInterestRate(uint256 _interestRatePerBlock) public {
        vm.assume(_interestRatePerBlock <= fixedInterestRateModel.BORROW_RATE_MAX_MANTISSA());
        fixedInterestRateModel.setInterestRate(_interestRatePerBlock);
        assertEq(_interestRatePerBlock, fixedInterestRateModel.interestRatePerBlock());
    }

    function testCannotSetInterestRateTooHigh(uint256 _interestRatePerBlock) public {
        vm.assume(_interestRatePerBlock > fixedInterestRateModel.BORROW_RATE_MAX_MANTISSA());
        vm.expectRevert(FixedInterestRateModel.BorrowRateExceeded.selector);
        fixedInterestRateModel.setInterestRate(_interestRatePerBlock);
    }
}
