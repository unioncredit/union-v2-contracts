pragma solidity ^0.8.0;
import {TestComptrollerBase} from "./TestComptrollerBase.sol";
import {FakeUserManager} from "./FakeUserManager.sol";

// TODO: test internal function individually too
contract TestCalculateRewards is TestComptrollerBase {
    function testGetRewardsMultiplierNonMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(erc20Mock));
        assertEq(multiplier, comptroller.nonMemberRatio());
    }

    function testGetRewardsMultiplierMember() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um));
        assertEq(true, um.checkIsMember(address(this)));
        uint256 multiplier = comptroller.getRewardsMultiplier(address(this), address(erc20Mock));
        assertEq(multiplier, comptroller.memberRatio());

        //member no stake
        FakeUserManager um2 = new FakeUserManager(0, 0, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um2));
        assertEq(true, um2.checkIsMember(address(this)));
        multiplier = comptroller.getRewardsMultiplier(address(this), address(erc20Mock));
        assertEq(multiplier, comptroller.memberRatio());

        //no member
        FakeUserManager um3 = new FakeUserManager(0, 0, 0, 0, 0, false);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um3));
        assertEq(false, um3.checkIsMember(address(this)));
        multiplier = comptroller.getRewardsMultiplier(address(this), address(erc20Mock));
        assertEq(multiplier, comptroller.nonMemberRatio());
    }

    function testCalculateRewards() public {
        FakeUserManager um = new FakeUserManager(100 ether, 100 ether, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um));
        comptroller.withdrawRewards(address(this), address(erc20Mock));
        skip(1000);
        uint256 rewards = comptroller.calculateRewards(address(this), address(erc20Mock));
        assertEq(rewards, 900000000000000000000 / 12);

        //no stake
        FakeUserManager um2 = new FakeUserManager(0, 0, 0, 0, 0, true);
        vm.prank(ADMIN);
        marketRegistryMock.setUserManager(address(erc20Mock), address(um2));
        comptroller.withdrawRewards(address(this), address(erc20Mock));
        skip(1000);
        rewards = comptroller.calculateRewards(address(this), address(erc20Mock));
        assertEq(rewards, 0);
    }

    function testInflationPerSecond0() public {
        uint256 inflation = comptroller.inflationPerSecond(1 ether);
        assertEq(inflation, 83_333_333_333_333_333); // 1000000000000000000 / 12
    }

    function testInflationPerSecond1() public {
        uint256 inflation = comptroller.inflationPerSecond(100 ether);
        assertEq(inflation, 900000000000000000 / 12);
    }

    function testInflationPerSecond2() public {
        uint256 inflation = comptroller.inflationPerSecond(1000 ether);
        assertEq(inflation, 66_666_666_666_666_667); // 800000000000000000 / 12
    }

    function testInflationPerSecond3() public {
        uint256 inflation = comptroller.inflationPerSecond(10000 ether);
        assertEq(inflation, 58_333_333_333_333_333); // 700000000000000000 / 12
    }

    function testInflationPerSecond4() public {
        uint256 inflation = comptroller.inflationPerSecond(100000 ether);
        assertEq(inflation, 600000000000000000 / 12);
    }

    function testInflationPerSecond5() public {
        uint256 inflation = comptroller.inflationPerSecond(1000000 ether);
        assertEq(inflation, 41_666_666_666_666_666); // 500000000000000000 / 12
    }

    function testInflationPerSecond6() public {
        uint256 inflation = comptroller.inflationPerSecond(5_000_000 ether);
        assertEq(inflation, 20_833_333_333_333_333); //250000000000000000 / 12
    }

    function testInflationPerSecond7() public {
        uint256 inflation = comptroller.inflationPerSecond(type(uint256).max);
        assertEq(inflation, 83_333_333_333); // 1000000000000 / 12
    }
}
