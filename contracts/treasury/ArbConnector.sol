//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IGatewayRouter} from "../interfaces/IGatewayRouter.sol";
import "../interfaces/IArbUnionWrapper.sol";

contract ArbConnector is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IArbUnionWrapper public immutable arbUnionWrapper;
    address public immutable target;

    event LogDeposit(address indexed caller, address destination, uint256 amount);

    constructor(
        IERC20 token_,
        IArbUnionWrapper arbUnionWrapper_,
        address target_
    ) {
        token = token_;
        arbUnionWrapper = arbUnionWrapper_;
        target = target_;
    }

    receive() external payable {}

    function approveToken() external {
        token.safeApprove(address(arbUnionWrapper), 0);
        token.safeApprove(address(arbUnionWrapper), type(uint256).max);
    }

    function bridge(
        uint256 maxGas,
        uint256 gasPriceBid,
        uint256 maxSubmissionCost
    ) external payable {
        uint256 amount = token.balanceOf(address(this));
        if (amount > 0) {
            require(arbUnionWrapper.wrap(amount), "wrap failed");
            uint256 transferAmount = arbUnionWrapper.balanceOf(address(this));
            bytes memory data = abi.encode(maxSubmissionCost, "");
            address gatewayRouter = arbUnionWrapper.router();
            IGatewayRouter(gatewayRouter).outboundTransfer{value: msg.value}(
                address(arbUnionWrapper),
                target,
                transferAmount,
                maxGas,
                gasPriceBid,
                data
            );

            emit LogDeposit(msg.sender, target, amount);
        }
    }

    function claimTokens(address recipient) external onlyOwner {
        require(recipient != address(0), "recipient cant be 0");
        uint256 wBalance = arbUnionWrapper.balanceOf(address(this));
        if (wBalance > 0) {
            arbUnionWrapper.unwrap(wBalance);
        }
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(recipient, balance);
        }
    }
}
