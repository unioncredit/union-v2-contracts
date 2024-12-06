pragma solidity ^0.8.0;
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TestUserManagerBase} from "./TestUserManagerBase.sol";
import {UserManager} from "union-v2-contracts/user/UserManager.sol";

contract TestUpdateFrozenInfo is TestUserManagerBase {
    using SafeCastUpgradeable for uint256;
    uint96 stakeAmount = (100 * UNIT).toUint96();
    uint96 lockAmount = 10;

    function setUp() public override {
        super.setUp();
        comptrollerMock.setUserManager(address(userManager));

        vm.startPrank(ADMIN);
        userManager.addMember(address(this));
        vm.stopPrank();

        userManager.stake(stakeAmount);
        userManager.updateTrust(ACCOUNT, stakeAmount);
    }

    function testUpdateFrozenInfo() public {
        vm.prank(address(userManager.uToken()));
        userManager.updateLocked(ACCOUNT, lockAmount, true);
        uTokenMock.setOverdueTime(0);
        uTokenMock.setLastRepay(1);
        skip(2);

        vm.prank(address(userManager.comptroller()));
        userManager.onWithdrawRewards(address(this));

        skip(3);
        (, , uint256 effectiveLocked, ) = userManager.getStakeInfo(address(this));

        assertEq(effectiveLocked, 0);
        assertEq(userManager.memberFrozen(address(this)), lockAmount);
        assertEq(userManager.totalFrozen(), lockAmount);
    }
}
