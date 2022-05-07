//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IDai.sol";
import "./UToken.sol";

contract UDai is UToken {
    function repayBorrowWithPermit(
        address borrower,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        IDai erc20Token = IDai(underlying);
        erc20Token.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);

        _repayBorrowFresh(msg.sender, borrower, amount);
    }
}
