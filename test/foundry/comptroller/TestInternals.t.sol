pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";

contract TestInternals is TestComptrollerBase {
    function setUp() public override {
        super.setUp();
        deployComtrollerExposedInternals();
    }

    function testGetInflationIndex() public {
        uint256[][] memory set = new uint256[][](3);

        set[0] = new uint256[](4);
        set[0][0] = 1 ether;
        set[0][1] = 1;
        set[0][2] = 0;
        set[0][3] = 1;

        set[1] = new uint256[](4);
        set[1][0] = 10000 ether;
        set[1][1] = 12;
        set[1][2] = 100;
        set[1][3] = 7000000000000012;

        set[2] = new uint256[](4);
        set[2][0] = 100000000 ether;
        set[2][1] = 100000000;
        set[2][2] = 100000000;
        set[2][3] = 10000000100000000;

        for (uint256 i = 0; i < set.length; i++) {
            uint256 res = comptrollerInternals.getInflationIndex(set[i][0], set[i][1], set[i][2]);
            assertEq(res, set[i][3]);
        }
    }

    function testLookup() public {
        uint256[][] memory set = new uint256[][](13);

        set[0] = new uint256[](2);
        set[0][0] = 0.00001 * 10**18 - 1;
        set[0][1] = 1 * 10**18;

        set[1] = new uint256[](2);
        set[1][0] = 0.0001 * 10**18 - 1;
        set[1][1] = 0.9 * 10**18;

        set[2] = new uint256[](2);
        set[2][0] = 0.001 * 10**18 - 1;
        set[2][1] = 0.8 * 10**18;

        set[3] = new uint256[](2);
        set[3][0] = 0.01 * 10**18 - 1;
        set[3][1] = 0.7 * 10**18;

        set[4] = new uint256[](2);
        set[4][0] = 0.1 * 10**18 - 1;
        set[4][1] = 0.6 * 10**18;

        set[5] = new uint256[](2);
        set[5][0] = 1 * 10**18 - 1;
        set[5][1] = 0.5 * 10**18;

        set[6] = new uint256[](2);
        set[6][0] = 5 * 10**18 - 1;
        set[6][1] = 0.25 * 10**18;

        set[7] = new uint256[](2);
        set[7][0] = 10 * 10**18 - 1;
        set[7][1] = 0.1 * 10**18;

        set[8] = new uint256[](2);
        set[8][0] = 100 * 10**18 - 1;
        set[8][1] = 0.01 * 10**18;

        set[9] = new uint256[](2);
        set[9][0] = 1000 * 10**18 - 1;
        set[9][1] = 0.001 * 10**18;

        set[10] = new uint256[](2);
        set[10][0] = 10000 * 10**18 - 1;
        set[10][1] = 0.0001 * 10**18;

        set[11] = new uint256[](2);
        set[11][0] = 100000 * 10**18 - 1;
        set[11][1] = 0.00001 * 10**18;

        set[12] = new uint256[](2);
        set[12][0] = 100000 * 10**18 + 1;
        set[12][1] = 0.000001 * 10**18;

        for (uint256 i = 0; i < set.length; i++) {
            uint256 res = comptrollerInternals.lookup(set[i][0]);
            assertEq(res, set[i][1]);
        }
    }
}
