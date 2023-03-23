pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {FakeUserManager} from "./FakeUserManager.sol";

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

        //member no stake
        FakeUserManager um2 = new FakeUserManager(0, 0, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um2));
        assertEq(true, um2.checkIsMember(address(this)));
        multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.memberRatio());

        //no member
        FakeUserManager um3 = new FakeUserManager(0, 0, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um3));
        assertEq(false, um3.checkIsMember(address(this)));
        multiplier = comptroller.getRewardsMultiplier(address(this), address(daiMock));
        assertEq(multiplier, comptroller.nonMemberRatio());
    }

    function testCalculateRewards() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um));
        comptroller.withdrawRewards(address(this), address(daiMock));
        vm.roll(1001);
        uint256 rewards = comptroller.calculateRewards(address(this), address(daiMock));
        assertEq(rewards, 900000000000000000000);

        //no stake
        FakeUserManager um2 = new FakeUserManager(0, 0, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(daiMock), address(um2));
        comptroller.withdrawRewards(address(this), address(daiMock));
        vm.roll(1001);
        rewards = comptroller.calculateRewards(address(this), address(daiMock));
        assertEq(rewards, 0);
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
