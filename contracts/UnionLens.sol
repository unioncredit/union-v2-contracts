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

        bool isMember = userManager.checkIsMember(user);
        uint256 stakedAmount = userManager.getStakerBalance(user);
        uint256 locked = userManager.getTotalLockedStake(user);

        userInfo.isOverdue = uToken.checkIsOverdue(user);
        userInfo.memberFrozen = userManager.memberFrozen(user);

        userInfo.isMember = isMember;
        userInfo.locked = locked;
        userInfo.stakedAmount = stakedAmount;

        userInfo.voucherCount = userManager.getVoucherCount(user);
        userInfo.voucheeCount = userManager.getVoucheeCount(user);

        userInfo.accountBorrow = uToken.getBorrowed(user);
    }

    function getBorrowerAddresses(address underlying, address account) public view returns (address[] memory) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));

        uint256 voucheeCount = userManager.getVoucheeCount(account);
        address[] memory addresses = new address[](voucheeCount);

        for (uint256 i = 0; i < voucheeCount; i++) {
            (address borrower, ) = userManager.vouchees(account, i);
            addresses[i] = borrower;
        }

        return addresses;
    }

    function getStakerAddresses(address underlying, address account) public view returns (address[] memory) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));

        uint256 voucherCount = userManager.getVoucherCount(account);
        address[] memory addresses = new address[](voucherCount);

        for (uint256 i = 0; i < voucherCount; i++) {
            (address staker, , ,) = userManager.vouchers(account, i);
            addresses[i] = staker;
        }

        return addresses;
    }

    function getVouchInfo(
        address underlying,
        address staker,
        address borrower
    ) public view returns (uint256, uint256, uint256, uint256) {
        IUserManager userManager = IUserManager(marketRegistry.userManagers(underlying));

        uint256 stakerStakedAmount = userManager.getStakerBalance(staker);

        bool isSet;
        uint256 idx;

        (isSet, idx) = userManager.voucherIndexes(borrower, staker);
        if (!isSet) {
            return (0, 0, 0, 0);
        }

        (, uint96 trust, uint96 locked, uint64 lastUpdated) = userManager.vouchers(borrower, idx);

        return (
            uint256(trust),
            uint256(trust) > stakerStakedAmount ? stakerStakedAmount : uint256(trust), // vouch
            uint256(locked),
            uint256(lastUpdated)
        );
    }

    function getRelatedInfo(
        address underlying,
        address staker,
        address borrower
    ) public view returns (RelatedInfo memory related) {
        (uint256 voucherTrust, uint256 voucherVouch, uint256 voucherLocked, uint256 voucherLastUpdated) = getVouchInfo(
            underlying,
            staker,
            borrower
        );

        (uint256 voucheeTrust, uint256 voucheeVouch, uint256 voucheeLocked, uint256 voucheeLastUpdated) = getVouchInfo(
            underlying,
            borrower,
            staker
        );

        related.voucher = VouchInfo(voucherTrust, voucherVouch, voucherLocked, voucherLastUpdated);

        related.vouchee = VouchInfo(voucheeTrust, voucheeVouch, voucheeLocked, voucheeLastUpdated);
    }
}
