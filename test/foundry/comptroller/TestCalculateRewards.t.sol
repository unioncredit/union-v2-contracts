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
    ) public {
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

    function getFrozenInfo(address, uint256) public view returns (uint256, uint256) {
        return (frozenCoinAge, totalFrozen);
    }

    function updateFrozenInfo(address, uint256) public returns (uint256, uint256) {
        return (frozenCoinAge, totalFrozen);
    }

    function checkIsMember(address) public view returns (bool) {
        return isMember;
    }
}

// TODO: test internal function individually too
contract TestCalculateRewards is TestComptrollerBase {
    function testGetRewardsMultiplierNonMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, false);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.nonMemberRatio());
    }

    function testGetRewardsMultiplierMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.memberRatio());
    }

    function testCalculateRewardsByBlocks() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        vm.prank(address(um));
        comptroller.withdrawRewards(address(this), address(daiMock));
        uint256 rewards = comptroller.calculateRewardsByBlocks(address(this), address(daiMock), 1000);
        assertEq(rewards, 900000000000000000000);
    }

    function testRewardsPerBlock0() public {
        uint256 rewards = comptroller.rewardsPerBlock(1 ether);
        assertEq(rewards, 1000000000000000000);
    }

    function testRewardsPerBlock1() public {
        uint256 rewards = comptroller.rewardsPerBlock(100 ether);
        assertEq(rewards, 900000000000000000);
    }

    function testRewardsPerBlock2() public {
        uint256 rewards = comptroller.rewardsPerBlock(1000 ether);
        assertEq(rewards, 800000000000000000);
    }

    function testRewardsPerBlock3() public {
        uint256 rewards = comptroller.rewardsPerBlock(10000 ether);
        assertEq(rewards, 700000000000000000);
    }

    function testRewardsPerBlock4() public {
        uint256 rewards = comptroller.rewardsPerBlock(100000 ether);
        assertEq(rewards, 600000000000000000);
    }

    function testRewardsPerBlock5() public {
        uint256 rewards = comptroller.rewardsPerBlock(1000000 ether);
        assertEq(rewards, 500000000000000000);
    }

    function testRewardsPerBlock6() public {
        uint256 rewards = comptroller.rewardsPerBlock(5_000_000 ether);
        assertEq(rewards, 250000000000000000);
    }

    function testRewardsPerBlock7() public {
        uint256 rewards = comptroller.rewardsPerBlock(type(uint256).max);
        assertEq(rewards, 1000000000000);
    }
}
