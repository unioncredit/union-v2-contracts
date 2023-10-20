//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title Comptroller Interface
 * @dev Work with UnionToken and UserManager to calculate the Union rewards based on the staking info from UserManager, and be ready to support multiple UserManagers for various tokens when we support multiple assets.
 */
interface IComptroller {
    function setHalfDecayPoint(uint256 point) external;

    function inflationPerSecond(uint256 effectiveTotalStake) external view returns (uint256);

    /**
     *  @dev Get the reward multiplier based on the account status
     *  @param account Account address
     *  @return Multiplier number (in wei)
     */
    function getRewardsMultiplier(address account, address token) external view returns (uint256);

    /**
     *  @dev Withdraw rewards
     *  @param account User address
     *  @param token address
     *  @return Amount of rewards
     */
    function withdrawRewards(address account, address token) external returns (uint256);

    function accrueRewards(address account, address token) external;

    function updateTotalStaked(address token, uint256 totalStaked) external returns (bool);

    /**
     *  @dev Calculate currently unclaimed rewards
     *  @param account Account address
     *  @param token address
     *  @return Unclaimed rewards
     */
    function calculateRewards(address account, address token) external view returns (uint256);
}
