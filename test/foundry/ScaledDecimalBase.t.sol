pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {ScaledDecimalBase} from "union-v2-contracts/ScaledDecimalBase.sol";

contract TestScaledDecimalBase is TestWrapper, ScaledDecimalBase {
    function setUp() public {}

    function testDecimalScaling() public {
        uint256 resp = decimalScaling(1e6 * 123, 6);
        assertEq(resp, 123 * 1e18);
        resp = decimalScaling(1e24 * 123, 24);
        assertEq(resp, 123 * 1e18);
    }

    function testDecimalReducing() public {
        uint256 resp = decimalScaling(1e6 * 123, 6);
        uint256 resp2 = decimalReducing(resp, 6);
        assertEq(resp2, 1e6 * 123);

        resp = decimalScaling(1e30 * 123, 30);
        resp2 = decimalReducing(resp, 30);
        assertEq(resp2, 1e30 * 123);
    }

    function testDecimalReducingRound() public {
        uint amount = 999999900000000000;
        uint expectAmount = 1000000;
        uint expectAmount2 = 999999;
        uint256 resp = decimalReducing(amount, 6, true);
        assertEq(resp, expectAmount);
        resp = decimalReducing(amount, 6, false);
        assertEq(resp, expectAmount2);
    }
}
