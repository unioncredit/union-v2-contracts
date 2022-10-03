pragma solidity ^0.8.0;
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";
import {Controller} from "union-v2-contracts/Controller.sol";

contract TestSettersAndQuery is TestUserManagerBase {
    function setUp() public override {
        super.setUp();
        vm.startPrank(MEMBER);
        userManager.stake(100 ether);
        userManager.updateTrust(ACCOUNT, 100 ether);
        vm.stopPrank();
    }

    function testCannotSetMaxStakeAmountNotAdmin(uint96 amount) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.setMaxStakeAmount(amount);
    }

    function testSetMaxStakeAmount(uint96 amount) public {
        vm.prank(ADMIN);
        userManager.setMaxStakeAmount(amount);
        uint256 maxStakeAmount = userManager.maxStakeAmount();
        assertEq(maxStakeAmount, amount);
    }

    function testCannotSetUTokenNotAdmin(address _uToken) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.setUToken(_uToken);
    }

    function testSetUToken(address _uToken) public {
        vm.assume(_uToken != address(0));
        vm.prank(ADMIN);
        userManager.setUToken(_uToken);
        address uToken = address(userManager.uToken());
        assertEq(_uToken, uToken);
    }

    function testCannotSetNewMemberFeeNotAdmin(uint96 amount) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.setNewMemberFee(amount);
    }

    function testSetNewMemberFee(uint96 amount) public {
        vm.prank(ADMIN);
        userManager.setNewMemberFee(amount);
        uint256 newMemberFee = userManager.newMemberFee();
        assertEq(newMemberFee, amount);
    }

    function testCannotSetMaxOverdueNotAdmin(uint96 amount) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.setMaxOverdueBlocks(amount);
    }

    function testSetMaxOverdue(uint96 amount) public {
        vm.prank(ADMIN);
        userManager.setMaxOverdueBlocks(amount);
        uint256 maxOverdue = userManager.maxOverdueBlocks();
        assertEq(maxOverdue, amount);
    }

    function testCannotSetEffectiveCountNotAdmin(uint256 count) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.setEffectiveCount(count);
    }

    function testSetEffectiveCount(uint256 count) public {
        vm.assume(count > 0 && count < 100);
        vm.prank(ADMIN);
        userManager.setEffectiveCount(count);
        uint256 effectiveCount = userManager.effectiveCount();
        assertEq(effectiveCount, count);
    }

    function testCannotAddMemberNotAdmin(address account) public {
        vm.expectRevert(Controller.SenderNotAdmin.selector);
        userManager.addMember(account);
    }

    function testAddMember(address account) public {
        vm.prank(ADMIN);
        userManager.addMember(account);
        bool isMember = userManager.checkIsMember(account);
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

    function testGetLockedStake(uint96 amount) public {
        vm.assume(amount <= 100 ether);
        vm.prank(address(uTokenMock));
        userManager.updateLocked(ACCOUNT, amount, true);
        uint256 lockedStake = userManager.getLockedStake(MEMBER, ACCOUNT);
        assertEq(lockedStake, amount);
    }

    function testGetTotalLockedStake(uint96 amount) public {
        vm.assume(amount <= 100 ether);
        vm.prank(address(uTokenMock));
        userManager.updateLocked(ACCOUNT, amount, true);
        uint256 lockedStake = userManager.getTotalLockedStake(MEMBER);
        assertEq(lockedStake, amount);
    }
}
