//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title UnionToken Interface
 * @dev Mint and distribute UnionTokens.
 */
interface IUnionToken is IERC20 {
    function owner() external view returns (address);

    function mint(address account, uint256 amount) external returns (bool);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function burnFrom(address account, uint256 amount) external;

    function disableWhitelist() external;
}
