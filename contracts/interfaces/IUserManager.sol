//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title UserManager Interface
 * @dev Manages the Union members credit lines, and their vouchees and borrowers info.
 */
interface IUserManager {
    function memberFrozen(address staker) external view returns (uint256);

    function stakers(address staker)
        external
        view
        returns (
            bool,
            uint96,
            uint96,
            uint64,
            uint256,
            uint256
        );

    function vouchers(address borrower, uint256 index)
        external
        view
        returns (
            address,
            uint96,
            uint96,
            uint64
        );

    function vouchees(address staker, uint256 index) external view returns (address, uint96);

    function voucherIndexes(address borrower, address staker) external view returns (bool, uint128);

    function voucheeIndexes(address borrower, address staker) external view returns (bool, uint128);

    function setMaxStakeAmount(uint96 maxStakeAmount) external;

    function setUToken(address uToken) external;

    function setNewMemberFee(uint256 amount) external;

    function setMaxOverdueBlocks(uint256 maxOverdueBlocks) external;

    function setEffectiveCount(uint256 effectiveCount) external;

    function getVoucherCount(address borrower) external view returns (uint256);

    function getVoucheeCount(address staker) external view returns (uint256);

    function getLockedStake(address staker, address borrower) external view returns (uint256);

    function getVouchingAmount(address staker, address borrower) external view returns (uint256);

    function registerMemberWithPermit(
        address newMember,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function withdrawRewards() external;

    function debtWriteOff(
        address staker,
        address borrower,
        uint96 amount
    ) external;

    /**
     *  @dev Check if the account is a valid member
     *  @param account Member address
     *  @return Address whether is member
     */
    function checkIsMember(address account) external view returns (bool);

    /**
     *  @dev Get the member's available credit line
     *  @param account Member address
     *  @return Limit
     */
    function getCreditLimit(address account) external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function totalFrozen() external view returns (uint256);

    function globalTotalStaked() external view returns (uint256);

    /**
     *  @dev Add a new member
     *  Accept claims only from the admin
     *  @param account Member address
     */
    function addMember(address account) external;

    /**
     *  @dev Update the trust amount for existing members.
     *  @param borrower Borrower address
     *  @param trustAmount Trust amount
     */
    function updateTrust(address borrower, uint96 trustAmount) external;

    /**
     *  @dev Apply for membership, and burn UnionToken as application fees
     *  @param newMember New member address
     */
    function registerMember(address newMember) external;

    /**
     *  @dev Stop vouch for other member.
     *  @param staker Staker address
     *  @param account Account address
     */
    function cancelVouch(address staker, address account) external;

    /**
     *  @dev Get the user's locked stake from all his backed loans
     *  @param staker Staker address
     *  @return LockedStake
     */
    function getTotalLockedStake(address staker) external view returns (uint256);

    /**
     *  @dev Get the staker's effective staked and locked amount
     *  @param staker Staker address
     *  @param pastBlocks Number of blocks since last rewards withdrawal
     *  @return  user's effective staked amount
     *           user's effective locked amount
     */
    function getStakeInfo(address staker, uint256 pastBlocks)
        external
        view
        returns (
            uint256,
            uint256,
            bool
        );

    /**
     * @dev Update the frozen info by the comptroller
     * @param staker Staker address
     * @param pastBlocks The past blocks
     * @return  effectStaked user's total stake - frozen
     *          effectLocked user's locked amount - frozen
     */
    function onWithdrawRewards(address staker, uint256 pastBlocks)
        external
        returns (
            uint256,
            uint256,
            bool
        );

    /**
     * @dev Update the frozen info by the utoken repay
     * @param borrower Borrower address
     */
    function onRepayBorrow(address borrower) external;

    /**
     *  @dev Update userManager locked info
     *  @param borrower Borrower address
     *  @param amount Borrow or repay amount(Including previously accrued interest)
     *  @param isBorrow True is borrow, false is repay
     */
    function updateLocked(
        address borrower,
        uint96 amount,
        bool isBorrow
    ) external;

    /**
     *  @dev Get the user's deposited stake amount
     *  @param account Member address
     *  @return Deposited stake amount
     */
    function getStakerBalance(address account) external view returns (uint256);

    /**
     *  @dev Stake
     *  @param amount Amount
     */
    function stake(uint96 amount) external;

    /**
     *  @dev Unstake
     *  @param amount Amount
     */
    function unstake(uint96 amount) external;
}
