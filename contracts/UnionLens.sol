//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUserManager} from "./interfaces/IUserManager.sol";

/**
 * @title UnionLens
 * @dev View functions for interfaces
 */
contract UnionLens {
    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Get the member's available credit limit
     *  @param borrower Member address
     *  @return total Credit line amount
     */
    function getCreditLimit(IUserManager userManager, address borrower) external view returns (uint256 total) {
        uint256 length = userManager.getVoucherCount(borrower);
        for (uint256 i = 0; i < length; i++) {
            (address staker, uint96 vouchAmount, uint96 vouchLocked, ) = userManager.vouchers(borrower, i);
            (, uint96 stakedAmount, uint96 stakeLocked) = userManager.stakers(staker);
            total += _min(stakedAmount - stakeLocked, vouchAmount - vouchLocked);
        }
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    function _min(uint96 a, uint96 b) private pure returns (uint96) {
        if (a < b) return a;
        return b;
    }
}
