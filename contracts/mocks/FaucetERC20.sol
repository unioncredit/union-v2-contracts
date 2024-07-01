//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// import {Test} from "forge-std/Test.sol";

contract FaucetERC20 is ERC20, ERC20Permit {
    uint8 public _decimals = 18;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function mint(address to, uint256 value) public returns (bool) {
        // require(value <= 10000000 ether, "dont be greedy");
        _mint(to, value);
        return true;
    }

    function burn(address to, uint256 value) public returns (bool) {
        _burn(to, value);
        return true;
    }

    function burnFrom(address account, uint256 amount) public virtual {
        _burn(account, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 newDecimals) public {
        _decimals = newDecimals;
    }
}
