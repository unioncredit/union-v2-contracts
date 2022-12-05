//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {UToken} from "./UToken.sol";

contract UErc20 is UToken {
    function repayBorrowWithERC20Permit(
        address borrower,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        IERC20Permit erc20Token = IERC20Permit(underlying);
        erc20Token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 interest = calculatingInterest(borrower);
        _repayBorrowFresh(msg.sender, borrower, amount, interest);
    }

    function repayInterestWithPermit(
        address borrower,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        IERC20Permit erc20Token = IERC20Permit(underlying);
        
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 interest = calculatingInterest(borrower);

        erc20Token.permit(msg.sender, address(this), interest, deadline, v, r, s);
        _repayBorrowFresh(msg.sender, borrower, interest, interest);
    }
}
