//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title UserManager Contract
 * @dev Manages the Union members credit lines, and their vouchees and borrowers info.
 */
contract UserManagerMock {
    uint256 public constant MAX_TRUST_LIMIT = 100;
    uint256 public constant MAX_STAKE_AMOUNT = 1000e18;

    uint256 public newMemberFee; // New member application fee
    uint256 public totalStaked;
    uint256 public totalFrozen;
    bool public isMember;
    uint256 public limit;
    uint256 public stakerBalance;
    uint256 public totalLockedStake;
    uint256 public totalFrozenAmount;

    constructor() {
        newMemberFee = 10**18; // Set the default membership fee
    }

    function batchUpdateTotalFrozen(address[] calldata account, bool[] calldata isOverdue) external {}

    function setNewMemberFee(uint256 amount) public {
        newMemberFee = amount;
    }

    function setIsMember(bool isMember_) public {
        isMember = isMember_;
    }

    function checkIsMember(address) public view returns (bool) {
        return isMember;
    }

    function setStakerBalance(uint256 stakerBalance_) public {
        stakerBalance = stakerBalance_;
    }

    function getStakerBalance(address) public view returns (uint256) {
        return stakerBalance;
    }

    function setTotalLockedStake(uint256 totalLockedStake_) public {
        totalLockedStake = totalLockedStake_;
    }

    function getTotalLockedStake(address) public view returns (uint256) {
        return totalLockedStake;
    }

    function setCreditLimit(uint256 limit_) public {
        limit = limit_;
    }

    function getCreditLimit(address) public view returns (uint256) {
        return limit;
    }

    function getLockedStake(address staker, address borrower) public view returns (uint256) {}

    function getVouchingAmount(address staker, address borrower) public view returns (uint256) {}

    function addMember(address account) public {}

    function updateTrust(address borrower_, uint96 trustAmount) external {}

    function cancelVouch(address staker, address borrower) external {}

    function registerMemberWithPermit(
        address newMember,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {}

    function registerMember(address newMember) public {}

    function stake(uint96 amount) public {}

    function unstake(uint96 amount) external {}

    function withdrawRewards() external {}

    function updateLocked(
        address borrower,
        uint96 amount,
        bool lock
    ) external {}

    //Only supports sumOfTrust
    function debtWriteOff(
        address staker,
        address borrower,
        uint96 amount
    ) public {}

    function onWithdrawRewards(address staker, uint256 pastBlocks) public returns (uint256, uint256) {}

    function onRepayBorrow(address borrower) public {}

    function getVoucherCount(address borrower) external view returns (uint256) {}

    function setEffectiveCount(uint256 effectiveCount) external {}

    function setMaxOverdueBlocks(uint256 maxOverdueBlocks) external {}

    function setMaxStakeAmount(uint96 maxStakeAmount) external {}

    function setUToken(address uToken) external {}
}
