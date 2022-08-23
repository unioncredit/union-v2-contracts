//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FaucetERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 value) public returns (bool) {
        // require(value <= 10000000 ether, "dont be greedy");
        _mint(to, value);
        return true;
    }

    function burn(address to, uint256 value) public returns (bool) {
        _burn(to, value);
        return true;
    }
}
