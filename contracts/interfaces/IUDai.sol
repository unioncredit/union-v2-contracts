//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IUDai {
    function repayBorrowWithPermit(
        address borrower,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
