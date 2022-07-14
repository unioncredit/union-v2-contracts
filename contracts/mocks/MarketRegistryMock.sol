//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

contract MarketRegistryMock {
    address public tokenA;
    address public tokenB;

    function addUToken(address token, address uToken) public {}

    function addUserManager(address token, address userManager) public {}

    function deleteMarket(address token) public {}

    function setTokens(address a, address b) public {
        tokenA = a;
        tokenB = b;
    }

    function tokens(address) public view returns (address, address) {
        return (tokenA, tokenB);
    }
}
