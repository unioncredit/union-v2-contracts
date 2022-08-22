//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

function Error(uint256 errorCode) public pure returns (string memory) {
    uint256 prefix = uint256(0x554e494f4e);

    assembly {
        let units := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        let formattedPrefix := shl(24, add(0x23, shl(8, prefix)))
        let revertReason := shl(184, add(formattedPrefix, add(add(units, shl(8, tenths)), shl(16, hundreds))))

        mstore(0x0, 0x0000000000000000000000000000000000000000000000000000000000000020)
        mstore(0x20, 9)
        mstore(0x40, revertReason)

        return(0x0, 0x60)
    }
}

library Errors {
    // TODO: 
    uint256 internal constant EXAMPLE = 0;
}
