pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {VouchFaucet} from "union-v2-contracts/peripheral/VouchFaucet.sol";

contract TestVouchFaucet is TestWrapper {
    VouchFaucet public vouchFaucet;

    uint256 public constant TRUST_AMOUNT = 10 ether;

    function setUp() public {
        deployMocks();
        vouchFaucet = new VouchFaucet(address(userManagerMock), TRUST_AMOUNT);
    }

    function testConfig() public {
        assertEq(vouchFaucet.USER_MANAGER(), address(userManagerMock));
        assertEq(vouchFaucet.TRUST_AMOUNT(), TRUST_AMOUNT);
        assertEq(vouchFaucet.STAKING_TOKEN(), userManagerMock.stakingToken());
    }

    function testSetMaxClaimable(address token, uint256 amount) public {
        vouchFaucet.setMaxClaimable(token, amount);
        assertEq(vouchFaucet.maxClaimable(token), amount);
    }

    function testCannotSetMaxClaimableNonAdmin(address token, uint256 amount) public {
        vm.prank(address(1234));
        vm.expectRevert("Ownable: caller is not the owner");
        vouchFaucet.setMaxClaimable(token, amount);
    }

    function testClaimVouch() public {
        vouchFaucet.claimVouch();
        uint256 trust = userManagerMock.trust(address(vouchFaucet), address(this));
        assertEq(trust, vouchFaucet.TRUST_AMOUNT());
    }

    function testStake() public {
        daiMock.mint(address(vouchFaucet), 1 ether);
        assertEq(userManagerMock.balances(address(vouchFaucet)), 0);
        vouchFaucet.stake();
        assertEq(userManagerMock.balances(address(vouchFaucet)), 1 ether);
    }

    function testExit() public {
        daiMock.mint(address(vouchFaucet), 1 ether);
        assertEq(userManagerMock.balances(address(vouchFaucet)), 0);
        vouchFaucet.stake();
        assertEq(userManagerMock.balances(address(vouchFaucet)), 1 ether);
        vouchFaucet.exit();
        assertEq(userManagerMock.balances(address(vouchFaucet)), 0);
    }

    function testTransferERC20(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(this) && to != address(vouchFaucet));

        daiMock.mint(address(vouchFaucet), amount);
        uint256 balBefore = daiMock.balanceOf(address(vouchFaucet));
        vouchFaucet.transferERC20(address(daiMock), to, amount);
        uint256 balAfter = daiMock.balanceOf(address(vouchFaucet));
        assertEq(balBefore - balAfter, amount);
        assertEq(daiMock.balanceOf(to), amount);
    }
}
