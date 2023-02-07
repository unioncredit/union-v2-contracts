pragma solidity ^0.8.0;

import {TestComptrollerBase} from "./TestComptrollerBase.sol";

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

    function getStakeInfo(address, uint256) public view returns (uint256, uint256, bool) {
        return (totalStaked, totalLockedStake, isMember);
    }

    function onWithdrawRewards(address, uint256) public view returns (uint256, uint256, bool) {
        return (totalStaked, totalLockedStake, isMember);
    }

    function checkIsMember(address) public view returns (bool) {
        return isMember;
    }

    function globalTotalStaked() external view returns (uint256 globalTotal) {
        globalTotal = totalStaked - totalFrozen;
        if (globalTotal < 1e18) {
            globalTotal = 1e18;
        }
    }
}

contract TestWithdrawRewards is TestComptrollerBase {
    function setUp() public override {
        super.setUp();
        unionTokenMock.mint(address(comptroller), 1_000_000 ether);
    }

    function testWithdrawRewards() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        uint256 balanceBefore = unionTokenMock.balanceOf(address(this));

        vm.startPrank(address(um));
        comptroller.withdrawRewards(address(this), address(daiMock));
        vm.roll(100);
        comptroller.withdrawRewards(address(this), address(daiMock));
        vm.stopPrank();

        uint256 balanceAfter = unionTokenMock.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);
    }
}
