//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract FaucetERC20_ERC20Permit is Initializable, ERC20PermitUpgradeable {
    function __FaucetERC20_ERC20Permit_init(string memory name_, string memory symbol_) public initializer {
        ERC20Upgradeable.__ERC20_init(name_, symbol_);
        ERC20PermitUpgradeable.__ERC20Permit_init(name_);
    }

    function mint(address account, uint256 mintAmount) external {
        _mint(account, mintAmount);
    }
}
