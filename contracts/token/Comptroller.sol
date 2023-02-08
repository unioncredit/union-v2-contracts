//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {Controller} from "../Controller.sol";
import {WadRayMath} from "../WadRayMath.sol";
import {IComptroller} from "../interfaces/IComptroller.sol";
import {IMarketRegistry} from "../interfaces/IMarketRegistry.sol";
import {IUserManager} from "../interfaces/IUserManager.sol";

/**
 *  @author Compound -> Union Finance
 *  @title Comptroller
 *  @dev  For the time being, only the reward calculation of a single
 *        token is supported, and the contract needs to be revised after
 *        determining the reward calculation scheme of multiple tokens
 */
contract Comptroller is Controller, IComptroller {
    using WadRayMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct Info {
        uint256 updatedBlock; //last withdraw rewards block
        uint256 inflationIndex; //last withdraw rewards inflationIndex
        uint256 accrued; //the unionToken accrued but not yet transferred to each user
    }

    struct UserManagerAccountState {
        uint256 effectiveStaked;
        uint256 effectiveLocked;
        bool isMember;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev Initial inflation index
     */
    uint256 public constant INIT_INFLATION_INDEX = 10 ** 18;

    /**
     * @dev Non member reward multiplier rate (75%)
     */
    uint256 public constant nonMemberRatio = 75 * 10 ** 16; // 75%;

    /**
     * @dev Member reward multiplier rate (100%)
     */
    uint256 public constant memberRatio = 10 ** 18;

    /**
     * @dev Half decay point to reduce rewards at
     */
    uint256 public halfDecayPoint;

    /**
     * @dev store the latest inflation index
     */
    uint256 public gInflationIndex;

    /**
     * @dev block number when updating the inflation index
     */
    uint256 public gLastUpdatedBlock;

    /**
     * @dev $UNION token contract
     */
    IERC20Upgradeable public unionToken;

    /**
     * @dev The market registry contract
     */
    IMarketRegistry public marketRegistry;

    /**
     * @dev Map account to token to Info
     */
    mapping(address => mapping(address => Info)) public users;

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Withdraw rewards event
     *  @param account The staker's address
     *  @param amount The amount of Union tokens to withdraw
     */
    event LogWithdrawRewards(address indexed account, uint256 amount);

    /* -------------------------------------------------------------------
      Errors
    ------------------------------------------------------------------- */

    error SenderNotUserManager();
    error NotZero();
    error FrozenCoinAge();
    error InflationIndexTooSmall();

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __Comptroller_init(
        address admin,
        address unionToken_,
        address marketRegistry_,
        uint256 _halfDecayPoint
    ) public initializer {
        Controller.__Controller_init(admin);

        gInflationIndex = INIT_INFLATION_INDEX;
        gLastUpdatedBlock = block.number;

        unionToken = IERC20Upgradeable(unionToken_);
        marketRegistry = IMarketRegistry(marketRegistry_);
        halfDecayPoint = _halfDecayPoint;
    }

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    modifier onlyUserManager(address token) {
        if (msg.sender != address(_getUserManager(token))) revert SenderNotUserManager();
        _;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    /**
     * @dev Set the half decay point
     */
    function setHalfDecayPoint(uint256 point) public onlyAdmin {
        if (point == 0) revert NotZero();
        halfDecayPoint = point;
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Get the reward multipier based on the account status
     *  @param account Account address
     *  @param token ERC20 token address
     *  @return Multiplier number (in wei)
     */
    function getRewardsMultiplier(address account, address token) external view override returns (uint256) {
        IUserManager userManager = _getUserManager(token);
        uint256 pastBlocks = block.number - users[account][token].updatedBlock;

        (uint256 effectiveStaked, uint256 effectiveLocked, bool isMember) = userManager.getStakeInfo(
            account,
            pastBlocks
        );
        return _getRewardsMultiplier(UserManagerAccountState(effectiveStaked, effectiveLocked, isMember));
    }

    /**
     *  @dev Calculate unclaimed rewards based on blocks
     *  @param account User address
     *  @param token Staking token address
     *  @param futureBlocks Number of blocks in the future
     *  @return Unclaimed rewards
     */
    function calculateRewardsByBlocks(
        address account,
        address token,
        uint256 futureBlocks
    ) public view override returns (uint256) {
        IUserManager userManager = _getUserManager(token);

        // Lookup account state from UserManager
        (UserManagerAccountState memory user, Info memory userInfo, uint256 pastBlocks) = _getUserInfoView(
            userManager,
            account,
            token,
            futureBlocks
        );

        return _calculateRewardsByBlocks(account, token, pastBlocks, userInfo, userManager.globalTotalStaked(), user);
    }

    /**
     *  @dev Calculate currently unclaimed rewards
     *  @param account Account address
     *  @param token Staking token address
     *  @return Unclaimed rewards
     */
    function calculateRewards(address account, address token) external view override returns (uint256) {
        return calculateRewardsByBlocks(account, token, 0);
    }

    /**
     *  @dev Calculate inflation per block
     *  @param effectiveTotalStake Effective total stake
     *  @return Inflation amount, div totalSupply is the inflation rate
     */
    function inflationPerBlock(uint256 effectiveTotalStake) public view returns (uint256) {
        return _inflationPerBlock(effectiveTotalStake);
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Withdraw rewards
     *  @param token Staking token address
     *  @return Amount of rewards
     */
    function withdrawRewards(address account, address token) external override whenNotPaused returns (uint256) {
        IUserManager userManager = _getUserManager(token);

        // Lookup account state from UserManager
        (UserManagerAccountState memory user, Info memory userInfo, uint256 pastBlocks) = _getUserInfo(
            userManager,
            account,
            token,
            0
        );

        // Lookup global state from UserManager
        uint256 globalTotalStaked = userManager.globalTotalStaked();

        uint256 amount = _calculateRewardsByBlocks(account, token, pastBlocks, userInfo, globalTotalStaked, user);

        // update the global states
        gInflationIndex = _getInflationIndexNew(globalTotalStaked, block.number - gLastUpdatedBlock);
        gLastUpdatedBlock = block.number;
        users[account][token].updatedBlock = block.number;
        users[account][token].inflationIndex = gInflationIndex;
        if (unionToken.balanceOf(address(this)) >= amount && amount > 0) {
            unionToken.safeTransfer(account, amount);
            users[account][token].accrued = 0;
            emit LogWithdrawRewards(account, amount);

            return amount;
        } else {
            users[account][token].accrued = amount;
            emit LogWithdrawRewards(account, 0);

            return 0;
        }
    }

    /**
     *  @dev When total staked change update inflation index
     *  @param totalStaked totalStaked amount
     *  @return Whether succeeded
     */
    function updateTotalStaked(
        address token,
        uint256 totalStaked
    ) external override whenNotPaused onlyUserManager(token) returns (bool) {
        if (totalStaked > 0) {
            gInflationIndex = _getInflationIndexNew(totalStaked, block.number - gLastUpdatedBlock);
        }
        gLastUpdatedBlock = block.number;

        return true;
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Get UserManager user specific state (view function does NOT update UserManage state)
     * @param userManager UserManager contract
     * @param account Account address
     * @param token Token address
     * @param futureBlocks Blocks in the future
     */
    function _getUserInfoView(
        IUserManager userManager,
        address account,
        address token,
        uint256 futureBlocks
    ) internal view returns (UserManagerAccountState memory user, Info memory userInfo, uint256 pastBlocks) {
        userInfo = users[account][token];
        uint256 lastUpdatedBlock = userInfo.updatedBlock;
        if (block.number < lastUpdatedBlock) {
            lastUpdatedBlock = block.number;
        }

        pastBlocks = block.number - lastUpdatedBlock + futureBlocks;

        (user.effectiveStaked, user.effectiveLocked, user.isMember) = userManager.getStakeInfo(account, pastBlocks);
    }

    /**
     * @dev Get UserManager user specific state (function does update UserManage state)
     * @param userManager UserManager contract
     * @param account Account address
     * @param token Token address
     * @param futureBlocks Blocks in the future
     */
    function _getUserInfo(
        IUserManager userManager,
        address account,
        address token,
        uint256 futureBlocks
    ) internal returns (UserManagerAccountState memory user, Info memory userInfo, uint256 pastBlocks) {
        userInfo = users[account][token];
        uint256 lastUpdatedBlock = userInfo.updatedBlock;
        if (block.number < lastUpdatedBlock) {
            lastUpdatedBlock = block.number;
        }

        pastBlocks = block.number - lastUpdatedBlock + futureBlocks;

        (user.effectiveStaked, user.effectiveLocked, user.isMember) = userManager.onWithdrawRewards(
            account,
            pastBlocks
        );
    }

    /**
     *  @dev Calculate currently unclaimed rewards
     *  @param account Account address
     *  @param token Staking token address
     *  @param pastBlocks # of blocks past
     *  @param userInfo User info
     *  @param totalStaked Effective total staked
     *  @param user User account global state
     *  @return Unclaimed rewards
     */
    function _calculateRewardsByBlocks(
        address account,
        address token,
        uint256 pastBlocks,
        Info memory userInfo,
        uint256 totalStaked,
        UserManagerAccountState memory user
    ) internal view returns (uint256) {
        uint256 startInflationIndex = users[account][token].inflationIndex;

        if (user.effectiveStaked == 0 || totalStaked == 0 || startInflationIndex == 0 || pastBlocks == 0) {
            return 0;
        }

        uint256 rewardMultiplier = _getRewardsMultiplier(user);

        uint256 curInflationIndex = _getInflationIndexNew(totalStaked, pastBlocks);

        if (curInflationIndex < startInflationIndex) revert InflationIndexTooSmall();

        return
            userInfo.accrued +
            (curInflationIndex - startInflationIndex).wadMul(user.effectiveStaked).wadMul(rewardMultiplier);
    }

    /**
     *  @dev Calculate new inflation index based on # of blocks
     *  @param totalStaked_ Number of total staked tokens in the system
     *  @param blockDelta Number of blocks
     *  @return New inflation index
     */
    function _getInflationIndexNew(uint256 totalStaked_, uint256 blockDelta) internal view returns (uint256) {
        if (totalStaked_ == 0) return INIT_INFLATION_INDEX;
        if (blockDelta == 0) return gInflationIndex;
        return _getInflationIndex(totalStaked_, gInflationIndex, blockDelta);
    }

    /**
     * @dev Get the UserManager contract. First try and load it from state
     * if it has been previously saved and fallback to loading it from the marketRegistry
     * @return userManager contract
     */
    function _getUserManager(address token) internal view returns (IUserManager) {
        return IUserManager(marketRegistry.userManagers(token));
    }

    /**
     *  @dev See Comptroller.inflationPerBlock
     */
    function _inflationPerBlock(uint256 effectiveTotalStake) internal view returns (uint256) {
        uint256 index = effectiveTotalStake / halfDecayPoint;
        return _lookup(index);
    }

    function _lookup(uint256 index) internal pure returns (uint256) {
        if (index <= 0.00001 * 10 ** 18) {
            return 1 * 10 ** 18;
        } else if (index <= 0.0001 * 10 ** 18) {
            return 0.9 * 10 ** 18;
        } else if (index <= 0.001 * 10 ** 18) {
            return 0.8 * 10 ** 18;
        } else if (index <= 0.01 * 10 ** 18) {
            return 0.7 * 10 ** 18;
        } else if (index <= 0.1 * 10 ** 18) {
            return 0.6 * 10 ** 18;
        } else if (index <= 1 * 10 ** 18) {
            return 0.5 * 10 ** 18;
        } else if (index <= 5 * 10 ** 18) {
            return 0.25 * 10 ** 18;
        } else if (index <= 10 * 10 ** 18) {
            return 0.1 * 10 ** 18;
        } else if (index <= 100 * 10 ** 18) {
            return 0.01 * 10 ** 18;
        } else if (index <= 1000 * 10 ** 18) {
            return 0.001 * 10 ** 18;
        } else if (index <= 10000 * 10 ** 18) {
            return 0.0001 * 10 ** 18;
        } else if (index <= 100000 * 10 ** 18) {
            return 0.00001 * 10 ** 18;
        } else {
            return 0.000001 * 10 ** 18;
        }
    }

    function _getInflationIndex(
        uint256 effectiveAmount,
        uint256 inflationIndex,
        uint256 blockDelta
    ) internal view returns (uint256) {
        return blockDelta * _inflationPerBlock(effectiveAmount).wadDiv(effectiveAmount) + inflationIndex;
    }

    function _getRewardsMultiplier(UserManagerAccountState memory user) internal pure returns (uint256) {
        if (user.isMember) {
            if (user.effectiveStaked == 0) {
                return memberRatio;
            }

            uint256 lendingRatio = user.effectiveLocked.wadDiv(user.effectiveStaked);

            return lendingRatio + memberRatio;
        } else {
            return nonMemberRatio;
        }
    }
}
