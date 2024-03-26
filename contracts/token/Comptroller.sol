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
     * @dev timestamp when updating the inflation index
     */
    uint256 public gLastUpdated;

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
        gLastUpdated = getTimestamp();

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
     *  @dev Get the reward multiplier based on the account status
     *  @param account Account address
     *  @param token ERC20 token address
     *  @return Multiplier number (in wei)
     */
    function getRewardsMultiplier(address account, address token) external view override returns (uint256) {
        IUserManager userManager = _getUserManager(token);
        (bool isMember, uint256 effectiveStaked, uint256 effectiveLocked, ) = userManager.getStakeInfoMantissa(account);
        return _getRewardsMultiplier(UserManagerAccountState(effectiveStaked, effectiveLocked, isMember));
    }

    /**
     *  @dev Calculate unclaimed rewards
     *  @param account Account address
     *  @param token Staking token address
     *  @return Unclaimed rewards
     */
    function calculateRewards(address account, address token) public view override returns (uint256) {
        IUserManager userManager = _getUserManager(token);

        // Lookup account state from UserManager
        UserManagerAccountState memory user = UserManagerAccountState(0, 0, false);
        (user.isMember, user.effectiveStaked, user.effectiveLocked, ) = userManager.getStakeInfoMantissa(account);

        return _calculateRewardsInternal(account, token, userManager.globalTotalStaked(), user);
    }

    /**
     *  @dev Calculate inflation per second
     *  @param effectiveTotalStake Effective total stake
     *  @return Inflation amount, div totalSupply is the inflation rate
     */
    function inflationPerSecond(uint256 effectiveTotalStake) public view returns (uint256) {
        return _inflationPerSecond(effectiveTotalStake);
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
        uint256 amount = _accrueRewards(account, token);
        if (amount > 0 && unionToken.balanceOf(address(this)) >= amount) {
            users[account][token].accrued = 0;
            unionToken.safeTransfer(account, amount);
            emit LogWithdrawRewards(account, amount);

            return amount;
        } else {
            users[account][token].accrued = amount;
            emit LogWithdrawRewards(account, 0);

            return 0;
        }
    }

    function accrueRewards(address account, address token) external override whenNotPaused {
        uint256 amount = _accrueRewards(account, token);
        users[account][token].accrued = amount;
    }

    function _accrueRewards(address account, address token) private returns (uint256) {
        IUserManager userManager = _getUserManager(token);

        // Lookup global state from UserManager
        uint256 globalTotalStaked = userManager.globalTotalStaked();

        // Lookup account state from UserManager
        UserManagerAccountState memory user = UserManagerAccountState(0, 0, false);
        (user.effectiveStaked, user.effectiveLocked, user.isMember) = userManager.onWithdrawRewards(account);

        uint256 amount = _calculateRewardsInternal(account, token, globalTotalStaked, user);

        // update the global states
        gInflationIndex = _getInflationIndexNew(globalTotalStaked, getTimestamp() - gLastUpdated);
        gLastUpdated = getTimestamp();
        users[account][token].inflationIndex = gInflationIndex;

        return amount;
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
            gInflationIndex = _getInflationIndexNew(totalStaked, getTimestamp() - gLastUpdated);
            gLastUpdated = getTimestamp();
        }

        return true;
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Calculate currently unclaimed rewards
     *  @param account Account address
     *  @param token Staking token address
     *  @param totalStaked Effective total staked
     *  @param user User account global state
     *  @return Unclaimed rewards
     */
    function _calculateRewardsInternal(
        address account,
        address token,
        uint256 totalStaked,
        UserManagerAccountState memory user
    ) internal view returns (uint256) {
        Info memory userInfo = users[account][token];
        uint256 startInflationIndex = userInfo.inflationIndex;
        if (startInflationIndex == 0) {
            return 0;
        }

        if (user.effectiveStaked == 0) {
            return userInfo.accrued;
        }

        uint256 rewardMultiplier = _getRewardsMultiplier(user);

        uint256 curInflationIndex = _getInflationIndexNew(totalStaked, getTimestamp() - gLastUpdated);

        if (curInflationIndex < startInflationIndex) revert InflationIndexTooSmall();

        return
            userInfo.accrued +
            (curInflationIndex - startInflationIndex).wadMul(user.effectiveStaked).wadMul(rewardMultiplier);
    }

    /**
     *  @dev Calculate new inflation index based on # of seconds
     *  @param totalStaked_ Number of total staked tokens in the system
     *  @param timeDelta Number of seconds passed
     *  @return New inflation index
     */
    function _getInflationIndexNew(uint256 totalStaked_, uint256 timeDelta) internal view returns (uint256) {
        if (timeDelta == 0 || totalStaked_ < 1e18) return gInflationIndex;
        return _getInflationIndex(totalStaked_, gInflationIndex, timeDelta);
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
     *  @dev See Comptroller.inflationPerSecond
     */
    function _inflationPerSecond(uint256 effectiveTotalStake) internal view returns (uint256) {
        uint256 index = effectiveTotalStake / halfDecayPoint;
        return _lookup(index);
    }

    function _lookup(uint256 index) internal pure returns (uint256) {
        if (index <= 0.00001 * 10 ** 18) {
            return 83_333_333_333_333_333; // 0.08333333333 * 10 ** 18;
        } else if (index <= 0.0001 * 10 ** 18) {
            return 75_000_000_000_000_000; // 0.075 * 10 ** 18;
        } else if (index <= 0.001 * 10 ** 18) {
            return 66_666_666_666_666_667; // 0.0666666667 * 10 ** 18;
        } else if (index <= 0.01 * 10 ** 18) {
            return 58_333_333_333_333_333; // 0.0583333333 * 10 ** 18;
        } else if (index <= 0.1 * 10 ** 18) {
            return 50_000_000_000_000_000; // 0.05 * 10 ** 18;
        } else if (index <= 1 * 10 ** 18) {
            return 41_666_666_666_666_666; // 0.0416666667 * 10 ** 18;
        } else if (index <= 5 * 10 ** 18) {
            return 20_833_333_333_333_333; // 0.0208333333 * 10 ** 18;
        } else if (index <= 10 * 10 ** 18) {
            return 8_333_333_333_333_333; // 0.0083333333 * 10 ** 18;
        } else if (index <= 100 * 10 ** 18) {
            return 833_333_333_333_333; // 0.0008333333 * 10 ** 18;
        } else if (index <= 1000 * 10 ** 18) {
            return 83_333_333_333_333; // 0.0000833333 * 10 ** 18;
        } else if (index <= 10000 * 10 ** 18) {
            return 8_333_333_333_333; // 0.0000083333 * 10 ** 18;
        } else if (index <= 100000 * 10 ** 18) {
            return 833_333_333_333; // 0.0000008333 * 10 ** 18;
        } else {
            return 83_333_333_333; // 0.0000000833 * 10 ** 18;
        }
    }

    function _getInflationIndex(
        uint256 effectiveAmount,
        uint256 inflationIndex,
        uint256 timeDelta
    ) internal view returns (uint256) {
        return timeDelta * _inflationPerSecond(effectiveAmount).wadDiv(effectiveAmount) + inflationIndex;
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

    /**
     *  @dev Function to simply retrieve block timestamp
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}
