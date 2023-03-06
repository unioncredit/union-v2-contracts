pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestOnRepayBorrow is TestUserManagerBase {
    address public BORROWER = address(123);
    address public STAKER = address(456);

    function setUp() public override {
        super.setUp();

        daiMock.mint(STAKER, 100 ether);

        vm.startPrank(userManager.admin());
        userManager.addMember(BORROWER);
        userManager.addMember(STAKER);
        vm.stopPrank();

        vm.startPrank(STAKER);
        userManager.updateTrust(BORROWER, 100 ether);
        daiMock.approve(address(userManager), 100 ether);
        userManager.stake(100 ether);
        vm.stopPrank();
    }

    function testOnRepayBorrow(uint256 borrowAmount) public {
        vm.assume(borrowAmount > 0 && borrowAmount < 100 ether);
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(BORROWER, borrowAmount, true);

        assert(userManager.getLockedStake(STAKER, BORROWER) > 0);

        uint256 frozenCoinBefore = userManager.frozenCoinAge(STAKER);

        vm.startPrank(address(userManager.uToken()));
        userManager.onRepayBorrow(BORROWER, 1);
        vm.stopPrank();

        uint256 frozenCoinAfter = userManager.frozenCoinAge(STAKER);
        assertEq(frozenCoinAfter - frozenCoinBefore, borrowAmount);
    }
}
