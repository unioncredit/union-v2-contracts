pragma solidity ^0.8.0;

import {TestWrapper} from "./TestWrapper.sol";
import {UnionLens} from "union-v2-contracts/UnionLens.sol";

contract TestUnionLens is TestWrapper {
    UnionLens public unionLens;
    address public constant ADMIN = address(0);

    function setUp() public virtual {
        deployMocks();
        vm.startPrank(ADMIN);
        marketRegistryMock.setUToken(address(daiMock), address(uTokenMock));
        marketRegistryMock.setUserManager(address(daiMock), address(userManagerMock));
        vm.stopPrank();
        unionLens = new UnionLens(marketRegistryMock);
    }

    function testGetStakerAddresses() public {
        address[] memory addresses = unionLens.getStakerAddresses(address(daiMock), address(1));
        assertEq(addresses.length, 0);

        userManagerMock.updateTrust(address(1), 1 ether);
        addresses = unionLens.getStakerAddresses(address(daiMock), address(1));
        assertEq(addresses.length, 1);
    }

    function testGetBorrowerAddresses() public {
        address[] memory addresses = unionLens.getBorrowerAddresses(address(daiMock), address(1));
        assertEq(addresses.length, 0);

        vm.startPrank(address(1));
        userManagerMock.updateTrust(address(2), 1 ether);
        addresses = unionLens.getBorrowerAddresses(address(daiMock), address(1));
        assertEq(addresses.length, 1);
        vm.stopPrank();
    }
}
