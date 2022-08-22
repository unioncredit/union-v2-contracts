pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";
import {UToken} from "union-v1.5-contracts/market/UToken.sol";

contract TestWriteOffDebt is TestUserManagerBase {
    address staker = MEMBER;
    address borrower = ACCOUNT;

    function setUp() public override {
        super.setUp();
        vm.startPrank(staker);
        userManager.stake(100 ether);
        userManager.updateTrust(borrower, 100 ether);
        vm.stopPrank();
        vm.mockCall(
            address(uTokenMock),
            abi.encodeWithSelector(UToken.checkIsOverdue.selector, borrower),
            abi.encode(true)
        );
    }

    function testCannotWriteOffDebtAmountZero() public {
        vm.expectRevert("UNION#401");
        userManager.debtWriteOff(staker, borrower, 0);
    }

    function testCannotWriteOffDebtNoAuth(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(address(3));
        vm.roll(1);
        vm.expectRevert("UNION#400");
        userManager.debtWriteOff(staker, borrower, amount);
    }

    function testCannotVoucherNotFound(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(address(3));
        vm.expectRevert("UNION#109");
        userManager.debtWriteOff(address(3), borrower, amount);
    }

    function testCannotWriteOffDebtExceedsLocked(uint96 amount) public {
        vm.assume(amount > 0);
        vm.prank(staker);
        vm.expectRevert("UNION#107");
        userManager.debtWriteOff(staker, borrower, amount);
    }

    function testDebtWriteOffPart(uint96 amount) public {
        vm.assume(amount > 0 && amount < 100 ether);
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, amount, true);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, amount);
        uint256 stakeAmount = userManager.getStakerBalance(staker);
        assertEq(stakeAmount, 100 ether - amount);

        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, true);
    }

    function testDebtWriteOffAll() public {
        vm.prank(address(uTokenMock));
        userManager.updateLocked(borrower, 100 ether, true);
        vm.prank(staker);
        userManager.debtWriteOff(staker, borrower, 100 ether);
        uint256 stakeAmount = userManager.getStakerBalance(staker);
        assertEq(stakeAmount, 0);

        (bool isSet, ) = userManager.voucherIndexes(borrower, staker);
        assertEq(isSet, false);
    }
}
