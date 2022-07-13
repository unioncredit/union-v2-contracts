pragma solidity ^0.8.0;

import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";
contract TestUserManagerStakeUnstake is TestUserManagerBase {
    address[] public MEMBERS = [address(10), address(11), address(12)];
    // uint96 stakeAmount = 100 ether;

    function setUp() public override {
        super.setUp();
        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();
    }
    
    function testStakeWithFuzzing(address ACCOUNT, uint96 stakeAmount) public {
        userManager.set(ACCOUNT, stakeAmount);
        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    // function testUnstakeWithFuzzing(uint96 stakeAmount) public {
    //     set(stakeAmount);
    //     userManager.stake(stakeAmount);
    //     userManager.updateTrust(ACCOUNT, stakeAmount);

    //     userManager.unstake(stakeAmount);
    // }
}
