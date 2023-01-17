//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUToken} from "./interfaces/IUToken.sol";
import {IUserManager} from "./interfaces/IUserManager.sol";
import {IMarketRegistry} from "./interfaces/IMarketRegistry.sol";

/**
 * @author Union
 * @title UnionLens is a view layer contract intended to be used by a UI
 */
contract UnionLens {
    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct UserInfo {
        bool isMember;
        bool isOverdue;
        uint256 memberFrozen;
        uint256 stakedAmount;
        uint256 locked;
        uint256 voucherCount;
        uint256 voucheeCount;
        uint256 accountBorrow;
    }

    struct VouchInfo {
        uint256 trust;
        uint256 vouch;
        uint256 locked;
        uint256 lastUpdated;
    }

    struct RelatedInfo {
        VouchInfo voucher;
        VouchInfo vouchee;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    IMarketRegistry public immutable marketRegistry;

    /* -------------------------------------------------------------------
      Constructor 
    ------------------------------------------------------------------- */

    constructor(IMarketRegistry _marketRegistry) {
        marketRegistry = _marketRegistry;
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    function getUserInfo(address underlying, address user) public view returns (UserInfo memory userInfo) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));
        IUToken uToken = IUToken(marketRegistry.uTokens(underlying));

        (bool isMember, uint96 stakedAmount, uint96 locked, , , ) = userManager.stakers(user);

        userInfo.isOverdue = uToken.checkIsOverdue(user);
        userInfo.memberFrozen = userManager.memberFrozen(user);

        userInfo.isMember = isMember;
        userInfo.locked = uint256(locked);
        userInfo.stakedAmount = uint256(stakedAmount);

        userInfo.voucherCount = userManager.getVoucherCount(user);
        userInfo.voucheeCount = userManager.getVoucheeCount(user);

        userInfo.accountBorrow = uToken.getBorrowed(user);
    }

    function getRelatedInfo(
        address underlying,
        address staker,
        address borrower
    ) public view returns (RelatedInfo memory related) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));

        (, uint96 stakerStakedAmount, , , , ) = userManager.stakers(staker);
        (, uint96 borrowerStakedAmount, , , , ) = userManager.stakers(borrower);

        bool isSet;
        uint256 idx;

        // Information about the relationship of this borrower to the
        // staker such as how much trust has this staker given the borrower
        // and how much of the vouch has this borrower locked
        (isSet, idx) = userManager.voucherIndexes(borrower, staker);
        if (isSet) {
            (, uint96 trust, uint96 locked, uint64 lastUpdated) = userManager.vouchers(borrower, idx);
            related.voucher = VouchInfo(
                uint256(trust),
                trust > stakerStakedAmount ? stakerStakedAmount : trust, // vouch
                uint256(locked),
                uint256(lastUpdated)
            );
        }

        // Information about the relationship of this staker to the borrower
        // How much trust has this staker given the borrower, what is the vouch
        (isSet, idx) = userManager.voucherIndexes(staker, borrower);
        if (isSet) {
            (, uint96 sTrust, uint96 sLocked, uint64 sLastUpdated) = userManager.vouchers(staker, idx);
            related.vouchee = VouchInfo(
                uint256(sTrust),
                sTrust > borrowerStakedAmount ? borrowerStakedAmount : sTrust, // vouch
                uint256(sLocked),
                uint256(sLastUpdated)
            );
        }
    }
}
