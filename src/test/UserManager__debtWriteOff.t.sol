pragma solidity ^0.8.0;

import "./Wrapper.sol";

contract TestUserManager__debtWriteOff is TestWrapper {
    function setUp() public override {
        super.setUp();
        assert(false);
    }

    function testDebtWriteOffStakedAmount() public {
        assert(false);
    }
    // function testDebtWriteOffVouchAmount() public {}
    // function testDebtWriteOffFrozenAmount() public {}
    // function testDebtWriteOffTotalFrozenAmount() public {}
    // function testDebtWriteOffTotalStakedAmount() public {}

    // function testCannotDebtWriteOffAmountZero() public {}
    // function testCannotDebtWriteOffNotOverdue() public {}
    // function testCannotDebtWriteOffMoreThanLocked() public {}
    // function testCannotDebtWriteOffNotPastMaxOverdue() public {}
    // function testCannotDebtWriteOffNotStaker() public {}
}
