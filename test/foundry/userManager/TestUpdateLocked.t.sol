pragma solidity ^0.8.0;

import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestUpdateLocked is TestUserManagerBase {
    using SafeCastUpgradeable for uint256;

    address[] public MEMBERS = [address(10), address(11), address(12)];
    uint96 stakeAmount = 100 ether;

    function setUp() public override {
        super.setUp();
        for (uint256 i = 0; i < MEMBERS.length; i++) {
            vm.prank(ADMIN);
            userManager.addMember(MEMBERS[i]);
            daiMock.mint(MEMBERS[i], stakeAmount);

            vm.startPrank(MEMBERS[i]);
            daiMock.approve(address(userManager), type(uint256).max);
            userManager.stake(stakeAmount);
            userManager.updateTrust(ACCOUNT, stakeAmount);
            vm.stopPrank();
        }
    }

    function _prankMarket() private {
        vm.startPrank(address(userManager.uToken()));
    }

    function testLocksFirstInFirst(uint96 lockAmount) public {
        vm.assume(lockAmount <= stakeAmount);
        _prankMarket();
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        (, , uint96 locked, ) = userManager.vouchers(ACCOUNT, 0);
        assertEq(locked, lockAmount);
    }

    function testUpdatesLastUpdated(uint96 lockAmount) public {
        uint64 lastUpdated;
        (, , , lastUpdated) = userManager.vouchers(ACCOUNT, 0);
        assertEq(lastUpdated, 0);

        vm.assume(lockAmount <= stakeAmount);
        _prankMarket();
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        (, , , lastUpdated) = userManager.vouchers(ACCOUNT, 0);
        assertEq(lastUpdated, block.timestamp);
    }

    function testLocksEntireCreditline() public {
        _prankMarket();
        uint96 lockAmount = (stakeAmount * MEMBERS.length).toUint96();
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();

        for (uint256 i = 0; i < MEMBERS.length; i++) {
            (, , uint96 locked, ) = userManager.vouchers(ACCOUNT, i);
            assertEq(locked, stakeAmount);
        }
    }

    function testUnlocksFirstInFirst() public {
        _prankMarket();
        uint96 lockAmount = (stakeAmount * MEMBERS.length).toUint96();
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        userManager.updateLocked(ACCOUNT, stakeAmount, false);
        vm.stopPrank();

        (, , uint96 locked, ) = userManager.vouchers(ACCOUNT, 0);
        assertEq(locked, 0);
    }

    function testCannotUpdateWithRemaining(uint96 lockAmount) public {
        vm.assume(lockAmount > (stakeAmount * MEMBERS.length).toUint96());
        _prankMarket();
        vm.expectRevert(UserManager.LockedRemaining.selector);
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        vm.stopPrank();
    }
}
