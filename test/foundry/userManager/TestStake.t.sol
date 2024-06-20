pragma solidity ^0.8.0;
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestStakeAndUnstake is TestUserManagerBase {
    using SafeCastUpgradeable for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testCannotStakeAboveLimit(uint96 amount) public {
        vm.assume(amount > 10000 * UNIT && amount < 9999999 * UNIT);
        vm.expectRevert(UserManager.StakeLimitReached.selector);
        userManager.stake(amount);
    }

    function testCannotStakeWhenDepositFailed(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.deposit.selector, erc20Mock, amount),
            abi.encode(false)
        );
        vm.expectRevert(UserManager.AssetManagerDepositFailed.selector);
        userManager.stake(amount);
        vm.clearMockedCalls();
    }

    function testStake(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT && amount > 1 * UNIT);
        vm.prank(MEMBER);
        userManager.stake(amount);
        uint256 stakeAmount = userManager.getStakerBalance(MEMBER);
        assertEq(stakeAmount, amount);
        uint256 totalStaked = userManager.totalStaked();
        uint256 totalFrozen = userManager.totalFrozen();
        assertEq(totalFrozen, 0);
        assertEq(totalStaked - totalFrozen, amount);
    }

    function testCannotUnstakeAboveStake(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT && amount > 0);
        vm.startPrank(MEMBER);
        userManager.stake(amount);
        vm.expectRevert(UserManager.InsufficientBalance.selector);
        userManager.unstake(amount + 1);
        vm.stopPrank();
    }

    function testCannotUnstakeWhenWithdrawFailed(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT && amount > 0);
        vm.startPrank(MEMBER);
        userManager.stake(amount);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, erc20Mock, MEMBER, amount),
            abi.encode(101 * UNIT)
        );
        vm.expectRevert(UserManager.AssetManagerWithdrawFailed.selector);
        userManager.unstake(amount);
        vm.stopPrank();
        vm.clearMockedCalls();
    }

    function testUnstake(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT && amount > 0);
        vm.startPrank(MEMBER);
        userManager.stake(amount);
        userManager.unstake(amount);
        uint256 stakeAmount = userManager.getStakerBalance(MEMBER);
        assertEq(stakeAmount, 0);
        vm.stopPrank();
    }

    function testUnstakeWhenRemaining(uint96 amount) public {
        vm.assume(amount <= 100 * UNIT && amount > 1 * UNIT);
        vm.startPrank(MEMBER);
        userManager.stake(amount);
        vm.mockCall(
            address(assetManagerMock),
            abi.encodeWithSelector(AssetManager.withdraw.selector, erc20Mock, MEMBER, amount),
            abi.encode(1 * UNIT)
        );
        userManager.unstake(amount);
        uint256 stakeAmount = userManager.getStakerBalance(MEMBER);
        assertEq(stakeAmount, 1 * UNIT);
        vm.stopPrank();
    }
}
