// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IArbToken {
    /**
     * @notice should increase token supply by amount, and should (probably) only be callable by the L1 bridge.
     */
    function bridgeMint(address _account, uint256 _amount) external;

    /**
     * @notice should decrease token supply by amount, and should (probably) only be callable by the L1 bridge.
     */
    function bridgeBurn(address _account, uint256 _amount) external;

    /**
     * @return address of layer 1 token
     */
    function l1Address() external view returns (address);
}
