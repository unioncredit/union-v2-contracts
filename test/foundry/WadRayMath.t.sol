pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {WadRayMath} from "union-v2-contracts/WadRayMath.sol";

contract TestWadRayMath is TestWrapper {
    function testWadMul() public {
        uint256 resp = WadRayMath.wadMul(1e18 * 123, 100);
        assertEq(resp, 12300);
    }

    function testWadDiv() public {
        uint256 resp = WadRayMath.wadDiv(100, 10);
        assertEq(resp, 10000000000000000000);
    }

    function testCannotWadMulWhenOverflow() public {
        vm.expectRevert(WadRayMath.MultiplicationOverflow.selector);
        WadRayMath.wadMul(115792089237316195423570985008687907853269984665640564039457584007913129639935, 2);
    }
}
