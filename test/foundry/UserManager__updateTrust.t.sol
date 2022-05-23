pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__updateTrust is TestWrapper {
    address public newMember = address(123);

    function testUpdateTrustRegisterMember() public {
        assert(!userManager.checkIsMember(MEMBER_4));
        initStakers();
        registerMember(MEMBER_4);
        assert(userManager.checkIsMember(MEMBER_4));
    }

    function testUpdateTrustGetCreditLimit() public {
        // stakers stake to underwrite credit line
        initStakers();
        registerMember(MEMBER_4);
        uint256 newCreditLimit = userManager.getCreditLimit(MEMBER_4);
        assertEq(newCreditLimit, trustAmount * 3);
    }

    function testUpdateTrustCreatesVouch(uint128 trustAmount) public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        userManager.updateTrust(newMember, trustAmount);
        (, uint256 vouchIndex) = userManager.voucherIndexes(newMember, address(this));
        (address staker, uint256 amount, uint256 outstanding) = userManager.vouchers(newMember, vouchIndex);
        vm.stopPrank();
        assertEq(staker, MEMBER_4);
        assertEq(amount, trustAmount);
        assertEq(outstanding, 0);
    }

    function testUpdateTrustExistingVouch(uint128 amount0, uint128 amount1) public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        userManager.updateTrust(newMember, amount0);
        (, uint256 vouchIndex) = userManager.voucherIndexes(newMember, MEMBER_4);
        (, uint256 amountBefore, ) = userManager.vouchers(newMember, vouchIndex);
        assertEq(amountBefore, amount0);
        userManager.updateTrust(newMember, amount1);
        (, uint256 amountAfter, ) = userManager.vouchers(newMember, vouchIndex);
        assertEq(amountAfter, amount1);
        vm.stopPrank();
    }

    function testUpdateTrustSavesVouchIndex() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        userManager.updateTrust(newMember, 100);
        (bool isSet, ) = userManager.voucherIndexes(newMember, MEMBER_4);
        assert(isSet);
        vm.stopPrank();
    }

    function testUpdateTrust1000() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        for (uint256 i = 0; i < 1000; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encode(i)))));
            userManager.updateTrust(addr, 100);
        }
        vm.stopPrank();
        // No assertions just no failure
    }

    function testCannotUpdateTrustOnZeroAddress() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        vm.expectRevert(UserManager.AddressZero.selector);
        userManager.updateTrust(address(0), 123);
        vm.stopPrank();
    }

    function testCannotUpdateTrustOnSelf() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        vm.expectRevert(UserManager.ErrorSelfVouching.selector);
        userManager.updateTrust(MEMBER_4, 123);
        vm.stopPrank();
    }

    function testCannotUpdateTrustNonMember() public {
        vm.expectRevert(UserManager.AuthFailed.selector);
        userManager.updateTrust(address(1234), 100);
    }

    function testCannotUpdateTrustLessThanOutstanding() public {
        initStakers();
        registerMember(MEMBER_4);
        vm.startPrank(MEMBER_4);
        uint256 creditLimit = userManager.getCreditLimit(MEMBER_4);
        uint256 fee = uToken.calculatingFee(creditLimit);
        uToken.borrow(creditLimit - fee);
        vm.stopPrank();

        vm.startPrank(MEMBER_1);
        vm.expectRevert(UserManager.TrustAmountTooSmall.selector);
        userManager.updateTrust(MEMBER_4, 0);
        vm.stopPrank();
    }
}
