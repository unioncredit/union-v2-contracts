//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interfaces/IDai.sol";
import "../interfaces/IUDai.sol";
import "./UToken.sol";

contract UDai is UToken, IUDai {
    function repayBorrowWithPermit(
        address borrower,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        IDai erc20Token = IDai(underlying);
        erc20Token.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);

        _repayBorrowFresh(msg.sender, borrower, amount);
    }
}
