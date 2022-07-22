pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";
import {AssetManager} from "union-v1.5-contracts/asset/AssetManager.sol";

contract TestStakeAndUnstake is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
    }

    function testCannotStakeAboveLimit() public {
        vm.expectRevert(UserManager.StakeLimitReached.selector);
        userManager.stake(1000000000 ether);
    }

    function testCannotStakeWhenDepositFailed() public {
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.deposit.selector, daiMock, 1 ether),
            abi.encode(false)
        );
        vm.expectRevert(UserManager.AssetManagerDepositFailed.selector);
        userManager.stake(1 ether);
        vm.clearMockedCalls();
    }

    function testStake() public {
        vm.prank(MEMBER);
        userManager.stake(1 ether);
        uint256 stakeAmount = userManager.getStakerBalance(MEMBER);
        assertEq(stakeAmount, 1 ether);
    }

    function testCannotUnstakeAboveStake() public {
        vm.startPrank(MEMBER);
        userManager.stake(1 ether);
        vm.expectRevert(UserManager.InsufficientBalance.selector);
        userManager.unstake(10 ether);
        vm.stopPrank();
    }

    function testCannotUnstakeWhenWithdrawFailed() public {
        vm.startPrank(MEMBER);
        userManager.stake(1 ether);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, daiMock, MEMBER, 1 ether),
            abi.encode(false)
        );
        vm.expectRevert(UserManager.AssetManagerWithdrawFailed.selector);
        userManager.unstake(1 ether);
        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testUnstake() public {
        vm.startPrank(MEMBER);
        userManager.stake(1 ether);
        userManager.unstake(1 ether);
        uint256 stakeAmount = userManager.getStakerBalance(MEMBER);
        assertEq(stakeAmount, 0);
        vm.stopPrank();
    }
}
