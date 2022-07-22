pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v1.5-contracts/user/UserManager.sol";

contract TestSettersAndQuery is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
        vm.startPrank(MEMBER);
        userManager.stake(100 ether);
        userManager.updateTrust(ACCOUNT, 100 ether);
        vm.stopPrank();
    }

    function testCannotSetMaxStakeAmountNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.setMaxStakeAmount(1);
    }

    function testSetMaxStakeAmount() public {
        vm.prank(ADMIN);
        userManager.setMaxStakeAmount(123);
        uint256 maxStakeAmount = userManager.maxStakeAmount();
        assertEq(maxStakeAmount, 123);
    }

    function testCannotSetUTokenNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.setUToken(address(3));
    }

    function testCannotSetUTokenZeroAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert(UserManager.AddressZero.selector);
        userManager.setUToken(address(0));
    }

    function testSetUToken() public {
        vm.prank(ADMIN);
        userManager.setUToken(address(4));
        address uToken = address(userManager.uToken());
        assertEq(uToken, address(4));
    }

    function testCannotSetNewMemberFeeNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.setNewMemberFee(123);
    }

    function testSetNewMemberFee() public {
        vm.prank(ADMIN);
        userManager.setNewMemberFee(123);
        uint256 newMemberFee = userManager.newMemberFee();
        assertEq(newMemberFee, 123);
    }

    function testCannotSetMaxOverdueNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.setMaxOverdue(123);
    }

    function testSetMaxOverdue() public {
        vm.prank(ADMIN);
        userManager.setMaxOverdue(123);
        uint256 maxOverdue = userManager.maxOverdue();
        assertEq(maxOverdue, 123);
    }

    function testCannotSetEffectiveCountNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.setEffectiveCount(2);
    }

    function testSetEffectiveCount() public {
        vm.prank(ADMIN);
        userManager.setEffectiveCount(2);
        uint256 effectiveCount = userManager.effectiveCount();
        assertEq(effectiveCount, 2);
    }

    function testCannotAddMemberNotAdmin() public {
        vm.expectRevert("Controller: not admin");
        userManager.addMember(ACCOUNT);
    }

    function testAddMember() public {
        vm.prank(ADMIN);
        userManager.addMember(ACCOUNT);
        bool isMember = userManager.checkIsMember(ACCOUNT);
        assertEq(isMember, true);
    }

    function testGetCreditLimit() public {
        uint256 creditLimit = userManager.getCreditLimit(ACCOUNT);
        assertEq(creditLimit, 100 ether);
    }

    function testGetVoucherCount() public {
        uint256 voucherCount = userManager.getVoucherCount(ACCOUNT);
        assertEq(voucherCount, 1);
    }

    function testGetStakerBalance() public {
        uint256 balance = userManager.getStakerBalance(MEMBER);
        assertEq(balance, 100 ether);
    }

    function testGetVouchingAmount() public {
        uint256 vouchingAmount = userManager.getVouchingAmount(MEMBER, ACCOUNT);
        assertEq(vouchingAmount, 100 ether);
    }

    function testGetLockedStake() public {
        vm.prank(address(uTokenMock));
        userManager.updateLocked(ACCOUNT, 50 ether, true);
        uint256 lockedStake = userManager.getLockedStake(MEMBER, ACCOUNT);
        assertEq(lockedStake, 50 ether);
    }

    function testGetTotalLockedStake() public {
        vm.prank(address(uTokenMock));
        userManager.updateLocked(ACCOUNT, 50 ether, true);
        uint256 lockedStake = userManager.getTotalLockedStake(MEMBER);
        assertEq(lockedStake, 50 ether);
    }
}
