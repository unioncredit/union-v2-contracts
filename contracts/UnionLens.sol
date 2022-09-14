//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUToken} from "./interfaces/IUToken.sol";
import {IUserManager} from "./interfaces/IUserManager.sol";
import {IMarketRegistry} from "./interfaces/IMarketRegistry.sol";

/**
 * @author Union
 * @title UnionLens
 */
contract UnionLens {
    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct UserInfo {
        bool isMember;
        uint256 memberFrozen;
        uint256 stakedAmount;
        uint256 locked;
        uint256 voucherCount;
        uint256 voucheeCount;
    }

    struct RelatedInfo {
        uint256 vouchTrustAmount;
        uint256 vouchLocked;
        uint256 vouchLastUpdated;
        uint256 voucheeAmount;
    }
    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    IMarketRegistry public marketRegistry;

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

        (bool isMember, uint96 locked, uint96 stakedAmount) = userManager.stakers(user);

        userInfo.memberFrozen = userManager.memberFrozen(user);

        userInfo.isMember = isMember;
        userInfo.locked = uint256(locked);
        userInfo.stakedAmount = uint256(stakedAmount);

        userInfo.voucherCount = userManager.getVoucherCount(user);
        userInfo.voucheeCount = userManager.getVoucheeCount(user);
    }

    function getRelatedInfo(
        address underlying,
        address staker,
        address borrower
    ) public view returns (RelatedInfo memory related) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));
        IUToken uToken = IUToken(marketRegistry.uTokens(underlying));

        bool isSet;
        uint256 idx;

        (isSet, idx) = userManager.voucheeIndexes(borrower, staker);
        if (isSet) {
            bytes32 vouchee = userManager.vouchees(staker, idx);
            (, uint256 amount) = _vouchee(vouchee);
            related.voucheeAmount = amount;
        }

        (isSet, idx) = userManager.voucherIndexes(borrower, staker);
        if (isSet) {
            (, uint96 amount, uint96 locked, uint64 lastUpdated) = userManager.vouchers(borrower, idx);
            related.vouchTrustAmount = uint256(amount);
            related.vouchLocked = uint256(locked);
            related.vouchLastUpdated = uint256(lastUpdated);
        }
    }

    /* -------------------------------------------------------------------
      Internal Functions 
    ------------------------------------------------------------------- */

    function _vouchee(bytes32 b) private pure returns (address addr, uint96 n) {
        addr = address(bytes20(b));
        n = uint96(bytes12(bytes20(uint160(2**160 - 1)) & (b << 160)));
    }
}
