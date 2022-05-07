pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__updateTrust is TestWrapper {
    function testUpdateTrustRegisterMember() public {
        assert(!userManager.checkIsMember(MEMBER_4));
        initStakers();
        registerMember(MEMBER_4);
        assert(userManager.checkIsMember(MEMBER_4));
    }

    function testUpdateTrustGetCreditLimit() public {
        registerMember(MEMBER_4);
        uint256 creditLimit = userManager.getCreditLimit(MEMBER_4);
        assertEq(creditLimit, 0);
        // stakers stake to underwrite credit line
        initStakers();
        uint256 newCreditLimit = userManager.getCreditLimit(MEMBER_4);
        assertEq(newCreditLimit, trustAmount * 3);
    }
}
