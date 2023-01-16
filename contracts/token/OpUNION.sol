//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {L2StandardERC20} from "@eth-optimism/contracts/standards/L2StandardERC20.sol";

import {Whitelistable} from "./Whitelistable.sol";

contract OpUNION is L2StandardERC20, ERC20Permit, Whitelistable {
    constructor(address _l2Bridge, address _l1Token)
        L2StandardERC20(_l2Bridge, _l1Token, "Optimism UNION", "OpUNION")
        ERC20Permit("Optimism UNION")
    {
        whitelistEnabled = false;
        whitelist(_l2Bridge);
    }

    /**
     * @dev ERC20 hook that is called before any transfer of tokens. This includes
     * minting and burning.
     * @param from Sender's address
     * @param to Receiver's address
     * @param amount Amount to transer
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (whitelistEnabled) {
            require(isWhitelisted(msg.sender) || to == address(0), "Whitelistable: address not whitelisted");
        }
    }

    /**
     * @dev ERC20 hook that is called after any transfer of tokens. This includes
     * minting and burning.
     * @param from Sender's address
     * @param to Receiver's address
     * @param amount Amount to transer
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);
    }
}
