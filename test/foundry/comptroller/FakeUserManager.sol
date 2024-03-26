pragma solidity ^0.8.0;

contract FakeUserManager {
    uint256 public totalStaked;

    uint256 public stakerBalance;
    uint256 public totalLockedStake;
    uint256 public frozenCoinAge;
    uint256 public totalFrozen;
    bool public isMember;

    constructor(
        uint256 _totalStaked,
        uint256 _stakerBalance,
        uint256 _totalLockedStake,
        uint256 _frozenCoinAge,
        uint256 _totalFrozen,
        bool _isMember
    ) {
        totalStaked = _totalStaked;
        stakerBalance = _stakerBalance;
        totalLockedStake = _totalLockedStake;
        frozenCoinAge = _frozenCoinAge;
        totalFrozen = _totalFrozen;
        isMember = _isMember;
    }

    function getStakerBalance(address) public view returns (uint256) {
        return stakerBalance;
    }

    function getTotalLockedStake(address) public view returns (uint256) {
        return totalLockedStake;
    }

    function getStakeInfo(address) public view returns (bool, uint256, uint256, uint256) {
        return (isMember, totalStaked, totalLockedStake, totalFrozen);
    }

    function getStakeInfoMantissa(address) public view returns (bool, uint256, uint256, uint256) {
        return (isMember, totalStaked, totalLockedStake, totalFrozen);
    }

    function onWithdrawRewards(address) public view returns (uint256, uint256, bool) {
        return (totalStaked, totalLockedStake, isMember);
    }

    function checkIsMember(address) public view returns (bool) {
        return isMember;
    }

    function globalTotalStaked() external view returns (uint256 globalTotal) {
        globalTotal = totalStaked - totalFrozen;
    }
}
