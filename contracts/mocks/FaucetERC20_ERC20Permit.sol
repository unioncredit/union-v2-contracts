//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract FaucetERC20_ERC20Permit is ERC20Permit {
    constructor(string memory name_, string memory symbol_) ERC20Permit(name_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 mintAmount) external {
        _mint(account, mintAmount);
    }

    function burnFrom(address account, uint256 amount) public {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, msg.sender, currentAllowance - amount);
        }
        _burn(account, amount);
    }
}
