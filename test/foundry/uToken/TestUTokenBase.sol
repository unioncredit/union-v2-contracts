pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {UToken} from "union-v2-contracts/market/UToken.sol";

contract TestUTokenBase is TestWrapper {
    UToken public uToken;
    address public constant ADMIN = address(1);
    address public constant ALICE = address(2);
    address public constant BOB = address(3);

    uint256 internal constant ORIGINATION_FEE = 0.01 ether;
    uint256 internal constant ORIGINATION_FEE_MAX = 0.05 ether;
    uint256 internal constant MIN_BORROW = 1 ether;
    uint256 internal constant MAX_BORROW = 100 ether;
    uint256 internal constant BORROW_INTEREST_PER_BLOCK = 0.000001 ether; //0.0001%
    uint256 internal constant OVERDUE_BLOCKS = 10;
    uint256 internal constant RESERVE_FACTOR = 0.5 ether;
    uint256 internal constant INIT_EXCHANGE_RATE = 1 ether;

    function setUp() public virtual {
        uint256 debtCeiling = 1000 ether;
        address uTokenLogic = address(new UToken());

        deployMocks();

        uToken = UToken(
            deployProxy(
                uTokenLogic,
                abi.encodeWithSignature(
                    "__UToken_init(string,string,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
                    "UTokenMock",
                    "UTM",
                    address(daiMock),
                    INIT_EXCHANGE_RATE,
                    RESERVE_FACTOR,
                    ORIGINATION_FEE,
                    ORIGINATION_FEE_MAX,
                    debtCeiling,
                    MAX_BORROW,
                    MIN_BORROW,
                    OVERDUE_BLOCKS,
                    ADMIN
                )
            )
        );

        vm.startPrank(ADMIN);
        uToken.setUserManager(address(userManagerMock));
        uToken.setAssetManager(address(assetManagerMock));
        uToken.setInterestRateModel(address(interestRateMock));
        vm.stopPrank();

        daiMock.mint(address(assetManagerMock), 100 ether);
        daiMock.mint(ALICE, 100 ether);
        daiMock.mint(BOB, 100 ether);

        userManagerMock.setIsMember(true);
    }
}
