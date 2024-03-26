pragma solidity ^0.8.0;

import {TestWrapper} from "../TestWrapper.sol";
import {ERC1155Voucher} from "union-v2-contracts/peripheral/ERC1155Voucher.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155("") {
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, bytes(""));
    }
}

contract TestERC1155Voucher is TestWrapper {
    ERC1155Voucher public voucher;
    TestERC1155 public token;
    address public ACC = address(123);

    uint256 public TRUST_AMOUNT = 10 * UNIT;

    function setUp() public {
        deployMocks();
        voucher = new ERC1155Voucher(address(userManagerMock), TRUST_AMOUNT);
        token = new TestERC1155();
        voucher.setIsValid(address(token), true);
    }

    function testConfig() public {
        assertEq(voucher.USER_MANAGER(), address(userManagerMock));
        assertEq(voucher.trustAmount(), TRUST_AMOUNT);
        assertEq(voucher.STAKING_TOKEN(), userManagerMock.stakingToken());
    }

    function testStake() public {
        erc20Mock.mint(address(voucher), 1 * UNIT);
        assertEq(userManagerMock.balances(address(voucher)), 0);
        voucher.stake();
        assertEq(userManagerMock.balances(address(voucher)), 1 * UNIT);
    }

    function testExit() public {
        erc20Mock.mint(address(voucher), 1 * UNIT);
        assertEq(userManagerMock.balances(address(voucher)), 0);
        voucher.stake();
        assertEq(userManagerMock.balances(address(voucher)), 1 * UNIT);
        voucher.exit();
        assertEq(userManagerMock.balances(address(voucher)), 0);
    }

    function testTransferERC20(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(this) && to != address(voucher));

        erc20Mock.mint(address(voucher), amount);
        uint256 balBefore = erc20Mock.balanceOf(address(voucher));
        voucher.transferERC20(address(erc20Mock), to, amount);
        uint256 balAfter = erc20Mock.balanceOf(address(voucher));
        assertEq(balBefore - balAfter, amount);
        assertEq(erc20Mock.balanceOf(to), amount);
    }

    function testTransferERC1155() public {
        uint256 tokenId = 1;
        uint256 amount = 1;
        vm.startPrank(ACC);
        token.mint(ACC, tokenId, amount);
        token.setApprovalForAll(address(voucher), true);
        assert(token.isApprovedForAll(ACC, address(voucher)));

        uint256 accBalBefore = token.balanceOf(ACC, tokenId);
        uint256 voucherBalBefore = token.balanceOf(address(voucher), tokenId);
        uint256 accTrustBefore = userManagerMock.trust(address(voucher), ACC);

        token.safeTransferFrom(ACC, address(voucher), tokenId, amount, bytes(""));

        uint256 accBalAfter = token.balanceOf(ACC, tokenId);
        uint256 voucherBalAfter = token.balanceOf(address(voucher), tokenId);
        uint256 accTrustAfter = userManagerMock.trust(address(voucher), ACC);

        assertEq(accBalBefore - accBalAfter, amount);
        assertEq(voucherBalAfter - voucherBalBefore, amount);
        assertEq(accTrustAfter - accTrustBefore, voucher.trustAmount());

        vm.stopPrank();
    }
}
