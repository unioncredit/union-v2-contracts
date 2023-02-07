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

    function _calculateCoinAge(address, uint256) public view returns (uint256, uint256, uint256) {
        return (totalStaked, totalLockedStake, totalFrozen);
    }

    function getStakeInfo(address, uint256) public view returns (uint256, uint256, bool) {
        return (totalStaked, totalLockedStake, isMember);
    }

    function onWithdrawRewards(address, uint256) public view returns (uint256, uint256, bool) {
        return (frozenCoinAge, totalFrozen, isMember);
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

// TODO: test internal function individually too
contract TestCalculateRewards is TestComptrollerBase {
    function testGetRewardsMultiplierNonMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.nonMemberRatio());
    }

    function testGetRewardsMultiplierMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        assertEq(true, um.checkIsMember(address(this)));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.memberRatio());
    }

    function testCalculateRewardsByBlocks() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        vm.prank(address(um));
        comptroller.withdrawRewards(address(this), address(daiMock));
        uint256 rewards = comptroller.calculateRewardsByBlocks(address(this), address(daiMock), 1000);
        assertEq(rewards, 900000000000000000000);
    }

    function testInflationPerBlock0() public {
        uint256 inflation = comptroller.inflationPerBlock(1 ether);
        assertEq(inflation, 1000000000000000000);
    }

    function testInflationPerBlock1() public {
        uint256 inflation = comptroller.inflationPerBlock(100 ether);
        assertEq(inflation, 900000000000000000);
    }

    function testInflationPerBlock2() public {
        uint256 inflation = comptroller.inflationPerBlock(1000 ether);
        assertEq(inflation, 800000000000000000);
    }

    function testInflationPerBlock3() public {
        uint256 inflation = comptroller.inflationPerBlock(10000 ether);
        assertEq(inflation, 700000000000000000);
    }

    function testInflationPerBlock4() public {
        uint256 inflation = comptroller.inflationPerBlock(100000 ether);
        assertEq(inflation, 600000000000000000);
    }

    function testInflationPerBlock5() public {
        uint256 inflation = comptroller.inflationPerBlock(1000000 ether);
        assertEq(inflation, 500000000000000000);
    }

    function testInflationPerBlock6() public {
        uint256 inflation = comptroller.inflationPerBlock(5_000_000 ether);
        assertEq(inflation, 250000000000000000);
    }

    function testInflationPerBlock7() public {
        uint256 inflation = comptroller.inflationPerBlock(type(uint256).max);
        assertEq(inflation, 1000000000000);
    }
}
