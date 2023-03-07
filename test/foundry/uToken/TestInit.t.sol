pragma solidity ^0.8.0;

import {TestUTokenBase} from "./TestUTokenBase.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";
import {AssetManager} from "union-v2-contracts/asset/AssetManager.sol";

contract TestInit is TestUTokenBase {
    function setUp() public override {
        super.setUp();
    }

    function testUTokenInit() public {
        uint256 debtCeiling = 1000 ether;
        address uTokenLogic = address(new UToken());
        UToken uToken = UToken(deployProxy(uTokenLogic, ""));

        uToken.__UToken_init(
            UToken.InitParams({
                name: "UTokenMock",
                symbol: "UTM",
                underlying: address(daiMock),
                initialExchangeRateMantissa: INIT_EXCHANGE_RATE,
                reserveFactorMantissa: RESERVE_FACTOR,
                originationFee: ORIGINATION_FEE,
                originationFeeMax: ORIGINATION_FEE_MAX,
                debtCeiling: debtCeiling,
                maxBorrow: MAX_BORROW,
                minBorrow: MIN_BORROW,
                overdueBlocks: OVERDUE_BLOCKS,
                admin: ADMIN
            })
        );

        assertEq(uToken.name(), "UTokenMock");
        assertEq(uToken.symbol(), "UTM");
        assertEq(uToken.underlying(), address(daiMock));
        assertEq(uToken.initialExchangeRateMantissa(), INIT_EXCHANGE_RATE);
        assertEq(uToken.reserveFactorMantissa(), RESERVE_FACTOR);
        assertEq(uToken.originationFee(), ORIGINATION_FEE);
        assertEq(uToken.originationFeeMax(), ORIGINATION_FEE_MAX);
        assertEq(uToken.debtCeiling(), debtCeiling);
        assertEq(uToken.maxBorrow(), MAX_BORROW);
        assertEq(uToken.minBorrow(), MIN_BORROW);
        assertEq(uToken.overdueBlocks(), OVERDUE_BLOCKS);
        assertEq(uToken.admin(), ADMIN);
    }
}
