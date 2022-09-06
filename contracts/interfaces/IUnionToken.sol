//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title UnionToken Interface
 * @dev Mint and distribute UnionTokens.
 */
interface IUnionToken {
    function owner() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

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
