//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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
contract Comptroller is Controller, IComptroller, ReentrancyGuardUpgradeable {
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

    struct UserManagerState {
        uint256 totalFrozen;
        uint256 totalStaked;
    }

    struct UserManagerAccountState {
        uint256 totalStaked;
        uint256 totalFrozen;
        uint256 totalLocked;
        uint256 pastBlocksFrozenCoinAge;
        bool isMember;
    }

    struct TokenState {
        // The token's last updated inflationIndex
        uint256 index;
        // The block number the index was last updated at
        uint256 lastBlock;
        bool isUToken;
        bool isSupport;
        //utoken needs to record totalstake, others are obtained from usermanager
        uint256 totalStaked;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev Initial inflation index
     */
    uint256 public constant INIT_INFLATION_INDEX = 10**18;

    /**
     * @dev Non member reward multiplier rate (75%)
     */
    uint256 public constant nonMemberRatio = 75 * 10**16; // 75%;

    /**
     * @dev Member reward multiplier rate (100%)
     */
    uint256 public constant memberRatio = 10**18;

    /**
     * @dev Half decay point to reduce rewards at
     */
    uint256 public halfDecayPoint;

    /**
     *  @dev Max amount that can be staked of the staking token
     */
    uint96 public maxStakeAmount;

    uint256 public initBlock;

    /**
     * @dev $UNION token contract
     */
    IERC20Upgradeable public unionToken;

    /**
     * @dev The market registry contract
     */
    IMarketRegistry public marketRegistry;

    /**
     * @dev The token state
     */
    mapping(address => TokenState) public tokenState;

    /**
     * @dev Map account to token to Info
     */
    mapping(address => mapping(address => Info)) public users;

    mapping(address => mapping(address => uint256)) public stakers; //user => utoken => stake amount
    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Withdraw rewards event
     *  @param account The staker's address
     *  @param amount The amount of Union tokens to withdraw
     */
    event LogWithdrawRewards(address indexed account, uint256 amount);

    /**
     *  @dev set max stake amount
     *  @param oldMaxStakeAmount Old amount
     *  @param newMaxStakeAmount New amount
     */
    event LogSetMaxStakeAmount(uint256 oldMaxStakeAmount, uint256 newMaxStakeAmount);

    /**
     *  @dev Stake event
     *  @param account The staker's address
     *  @param uToken The utoken address
     *  @param amount The amount of tokens to stake
     */
    event LogStake(address indexed account, address indexed uToken, uint256 amount);

    /**
     *  @dev Unstake event
     *  @param account The staker's address
     *  @param uToken The utoken address
     *  @param amount The amount of tokens to unstake
     */
    event LogUnstake(address indexed account, address indexed uToken, uint256 amount);

    /* -------------------------------------------------------------------
      Errors
    ------------------------------------------------------------------- */

    error SenderNotUserManager();
    error NotZero();
    error FrozenCoinAge();
    error InflationIndexTooSmall();
    error StakeLimitReached();
    error NotExit();
    error NotSupport();
    error ExceedStake();

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __Comptroller_init(
        address unionToken_,
        address marketRegistry_,
        uint256 _halfDecayPoint
    ) public initializer {
        Controller.__Controller_init(msg.sender);
        initBlock = block.number;
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

    function setSupportUToken(address token, bool isSupport) public onlyAdmin {
        if (!marketRegistry.hasUToken(token)) revert NotExit();
        address uToken = marketRegistry.uTokens(token);

        //initialization
        if (tokenState[uToken].index == 0) {
            tokenState[uToken].isUToken = true;
            tokenState[uToken].index = INIT_INFLATION_INDEX;
            tokenState[uToken].lastBlock = block.number;
        }
        tokenState[uToken].isSupport = isSupport;
    }

    /**
     * @dev Set the max amount that a user can stake
     * Emits {LogSetMaxStakeAmount} event
     * @param maxStakeAmount_ The max stake amount
     */
    function setMaxStakeAmount(uint96 maxStakeAmount_) external onlyAdmin {
        uint96 oldMaxStakeAmount = maxStakeAmount;
        maxStakeAmount = maxStakeAmount_;
        emit LogSetMaxStakeAmount(uint256(oldMaxStakeAmount), uint256(maxStakeAmount));
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
        IUserManager userManagerContract = _getUserManager(token);
        uint256 stakingAmount = userManagerContract.getStakerBalance(account);
        uint256 lockedStake = userManagerContract.getTotalLockedStake(account);
        (uint256 totalFrozen, ) = userManagerContract.getFrozenInfo(account, block.number);
        bool isMember = userManagerContract.checkIsMember(account);
        return _getRewardsMultiplier(stakingAmount, lockedStake, totalFrozen, isMember);
    }

    function getUTokenRewardsMultiplier() external pure override returns (uint256) {
        return _getUTokenRewardsMultiplier();
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

        // Lookup account stataddress accounte from UserManager
        (
            UserManagerAccountState memory userManagerAccountState,
            Info memory userInfo,
            uint256 pastBlocks
        ) = _getUserInfoView(address(userManager), account, token, futureBlocks);

        // Lookup global state from UserManager
        UserManagerState memory userManagerState = _getUserManagerState(userManager);

        return
            _calculateRewardsByBlocks(account, token, pastBlocks, userInfo, userManagerState, userManagerAccountState);
    }

    function calculateUTokenRewardsByBlocks(
        address account,
        address token,
        uint256 futureBlocks
    ) public view override returns (uint256) {
        if (!tokenState[token].isSupport) return 0;
        (
            UserManagerAccountState memory userManagerAccountState,
            Info memory userInfo,
            uint256 pastBlocks
        ) = _getUserInfoView(address(0), account, token, futureBlocks);

        UserManagerState memory userManagerState;
        userManagerState.totalStaked = tokenState[token].totalStaked;
        if (userManagerState.totalStaked < 1e18) {
            userManagerState.totalStaked = 1e18;
        }

        return
            _calculateRewardsByBlocks(account, token, pastBlocks, userInfo, userManagerState, userManagerAccountState);
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
    function stake(address utoken, uint96 amount) public whenNotPaused nonReentrant {
        if (!tokenState[utoken].isSupport) revert NotSupport();
        IERC20Upgradeable erc20Token = IERC20Upgradeable(utoken);
        withdrawUTokenRewards(utoken);

        if (stakers[msg.sender][utoken] + amount > maxStakeAmount) revert StakeLimitReached();

        stakers[msg.sender][utoken] += amount;
        tokenState[utoken].totalStaked += amount;

        erc20Token.safeTransferFrom(msg.sender, address(this), amount);

        emit LogStake(msg.sender, utoken, amount);
    }

    function unstake(address utoken, uint96 amount) external whenNotPaused nonReentrant {
        if (!tokenState[utoken].isSupport) revert NotSupport();
        if (stakers[msg.sender][utoken] < amount) revert ExceedStake();
        IERC20Upgradeable erc20Token = IERC20Upgradeable(utoken);
        withdrawUTokenRewards(utoken);

        stakers[msg.sender][utoken] -= amount;
        tokenState[utoken].totalStaked -= amount;

        erc20Token.safeTransfer(msg.sender, amount);
        emit LogUnstake(msg.sender, utoken, amount);
    }

    function withdrawUTokenRewards(address uToken) public override whenNotPaused returns (uint256) {
        if (!tokenState[uToken].isSupport) revert NotSupport();
        (
            UserManagerAccountState memory userManagerAccountState,
            Info memory userInfo,
            uint256 pastBlocks
        ) = _getUserInfo(address(0), msg.sender, uToken, 0);

        UserManagerState memory userManagerState;
        userManagerState.totalStaked = tokenState[uToken].totalStaked;
        if (userManagerState.totalStaked < 1e18) {
            userManagerState.totalStaked = 1e18;
        }

        uint256 amount = _calculateRewardsByBlocks(
            msg.sender,
            uToken,
            pastBlocks,
            userInfo,
            userManagerState,
            userManagerAccountState
        );

        // update the global states
        uint256 totalStaked_ = userManagerState.totalStaked;
        uint256 blockDelta = tokenState[uToken].lastBlock > 0
            ? block.number - tokenState[uToken].lastBlock
            : block.number - initBlock;
        tokenState[uToken].index = _getInflationIndexNew(uToken, totalStaked_, blockDelta);
        tokenState[uToken].lastBlock = block.number;
        users[msg.sender][uToken].updatedBlock = block.number;
        users[msg.sender][uToken].inflationIndex = tokenState[uToken].index;
        if (unionToken.balanceOf(address(this)) >= amount && amount > 0) {
            unionToken.safeTransfer(msg.sender, amount);
            users[msg.sender][uToken].accrued = 0;
            emit LogWithdrawRewards(msg.sender, amount);

            return amount;
        } else {
            users[msg.sender][uToken].accrued = amount;
            emit LogWithdrawRewards(msg.sender, 0);

            return 0;
        }
    }

    /**
     *  @dev Withdraw rewards
     *  @param token Staking token address
     *  @return Amount of rewards
     */
    function withdrawRewards(address account, address token)
        external
        override
        whenNotPaused
        onlyUserManager(token)
        returns (uint256)
    {
        IUserManager userManager = _getUserManager(token);

        // Lookup account state from UserManager
        (
            UserManagerAccountState memory userManagerAccountState,
            Info memory userInfo,
            uint256 pastBlocks
        ) = _getUserInfo(address(userManager), account, token, 0);

        // Lookup global state from UserManager
        UserManagerState memory userManagerState = _getUserManagerState(userManager);

        uint256 amount = _calculateRewardsByBlocks(
            account,
            token,
            pastBlocks,
            userInfo,
            userManagerState,
            userManagerAccountState
        );

        // update the global states
        uint256 totalStaked_ = userManagerState.totalStaked - userManagerState.totalFrozen;
        uint256 blockDelta = tokenState[token].lastBlock > 0
            ? block.number - tokenState[token].lastBlock
            : block.number - initBlock;
        tokenState[token].index = _getInflationIndexNew(token, totalStaked_, blockDelta);
        tokenState[token].lastBlock = block.number;
        users[account][token].updatedBlock = block.number;
        users[account][token].inflationIndex = tokenState[token].index;
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
    function updateTotalStaked(address token, uint256 totalStaked)
        external
        override
        whenNotPaused
        onlyUserManager(token)
        returns (bool)
    {
        if (totalStaked > 0) {
            uint256 blockDelta = tokenState[token].lastBlock > 0
                ? block.number - tokenState[token].lastBlock
                : block.number - initBlock;
            tokenState[token].index = _getInflationIndexNew(token, totalStaked, blockDelta);
        }
        tokenState[token].lastBlock = block.number;

        return true;
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Get UserManager global state values
     */
    function _getUserManagerState(IUserManager userManager) internal view returns (UserManagerState memory) {
        UserManagerState memory userManagerState;

        userManagerState.totalFrozen = userManager.totalFrozen();
        userManagerState.totalStaked = userManager.totalStaked() - userManagerState.totalFrozen;
        if (userManagerState.totalStaked < 1e18) {
            userManagerState.totalStaked = 1e18;
        }

        return userManagerState;
    }

    /**
     * @dev Get UserManager user specific state (view function does NOT update UserManage state)
     * @param userManagerAddress UserManager contract
     * @param account Account address
     * @param token Token address
     * @param futureBlocks Blocks in the future
     */
    function _getUserInfoView(
        address userManagerAddress,
        address account,
        address token,
        uint256 futureBlocks
    )
        internal
        view
        returns (
            UserManagerAccountState memory,
            Info memory,
            uint256
        )
    {
        IUserManager userManager = IUserManager(userManagerAddress);
        Info memory userInfo = users[account][token];
        uint256 lastUpdatedBlock = userInfo.updatedBlock;
        if (block.number < lastUpdatedBlock) {
            lastUpdatedBlock = block.number;
        }

        uint256 pastBlocks = block.number - lastUpdatedBlock + futureBlocks;

        UserManagerAccountState memory userManagerAccountState;
        if (address(userManager) != address(0)) {
            (userManagerAccountState.totalFrozen, userManagerAccountState.pastBlocksFrozenCoinAge) = userManager
                .getFrozenInfo(account, pastBlocks);
        }

        return (userManagerAccountState, userInfo, pastBlocks);
    }

    /**
     * @dev Get UserManager user specific state (function does update UserManage state)
     * @param userManagerAddress UserManager contract
     * @param account Account address
     * @param token Token address
     * @param futureBlocks Blocks in the future
     */
    function _getUserInfo(
        address userManagerAddress,
        address account,
        address token,
        uint256 futureBlocks
    )
        internal
        returns (
            UserManagerAccountState memory,
            Info memory,
            uint256
        )
    {
        Info memory userInfo = users[account][token];
        uint256 lastUpdatedBlock = userInfo.updatedBlock;
        if (block.number < lastUpdatedBlock) {
            lastUpdatedBlock = block.number;
        }

        uint256 pastBlocks = block.number - lastUpdatedBlock + futureBlocks;

        UserManagerAccountState memory userManagerAccountState;
        if (userManagerAddress != address(0)) {
            IUserManager userManager = IUserManager(userManagerAddress);
            (userManagerAccountState.totalFrozen, userManagerAccountState.pastBlocksFrozenCoinAge) = userManager
                .updateFrozenInfo(account, pastBlocks);
        }

        return (userManagerAccountState, userInfo, pastBlocks);
    }

    /**
     *  @dev Calculate currently unclaimed rewards
     *  @param account Account address
     *  @param token Staking token address
     *  @param userManagerState User manager global state
     *  @return Unclaimed rewards
     */
    function _calculateRewardsByBlocks(
        address account,
        address token,
        uint256 pastBlocks,
        Info memory userInfo,
        UserManagerState memory userManagerState,
        UserManagerAccountState memory userManagerAccountState
    ) internal view returns (uint256) {
        uint256 multiplier;
        if (tokenState[token].isUToken) {
            userManagerAccountState.totalStaked = stakers[account][token];
            multiplier = _getUTokenRewardsMultiplier();
        } else {
            IUserManager userManagerContract = _getUserManager(token);

            // Lookup account state from UserManager
            userManagerAccountState.totalStaked = userManagerContract.getStakerBalance(account);
            userManagerAccountState.totalLocked = userManagerContract.getTotalLockedStake(account);
            userManagerAccountState.isMember = userManagerContract.checkIsMember(account);

            multiplier = _getRewardsMultiplier(
                userManagerAccountState.totalStaked,
                userManagerAccountState.totalLocked,
                userManagerAccountState.totalFrozen,
                userManagerAccountState.isMember
            );
        }

        return
            userInfo.accrued +
            _calculateRewards(
                account,
                token,
                userManagerState.totalStaked,
                userManagerAccountState.totalStaked,
                userManagerAccountState.pastBlocksFrozenCoinAge,
                pastBlocks,
                multiplier
            );
    }

    /**
     *  @dev Calculate new inflation index based on # of blocks
     *  @param totalStaked_ Number of total staked tokens in the system
     *  @param blockDelta Number of blocks
     *  @return New inflation index
     */
    function _getInflationIndexNew(
        address token,
        uint256 totalStaked_,
        uint256 blockDelta
    ) internal view returns (uint256) {
        uint256 inflationIndex = tokenState[token].index > 0 ? tokenState[token].index : INIT_INFLATION_INDEX;
        if (totalStaked_ == 0) return INIT_INFLATION_INDEX;
        if (blockDelta == 0) return inflationIndex;
        return _getInflationIndex(totalStaked_, inflationIndex, blockDelta);
    }

    function _calculateRewards(
        address account,
        address token,
        uint256 totalStaked,
        uint256 userStaked,
        uint256 frozenCoinAge,
        uint256 pastBlocks,
        uint256 multiplier
    ) internal view returns (uint256) {
        uint256 startInflationIndex = users[account][token].inflationIndex;
        if (userStaked * pastBlocks < frozenCoinAge) revert FrozenCoinAge();

        if (userStaked == 0 || totalStaked == 0 || startInflationIndex == 0 || pastBlocks == 0) {
            return 0;
        }

        uint256 effectiveStakeAmount = (userStaked * pastBlocks - frozenCoinAge) / pastBlocks;

        uint256 curInflationIndex = _getInflationIndexNew(token, totalStaked, pastBlocks);

        if (curInflationIndex < startInflationIndex) revert InflationIndexTooSmall();

        return (curInflationIndex - startInflationIndex).wadMul(effectiveStakeAmount).wadMul(multiplier);
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
        if (index <= 0.00001 * 10**18) {
            return 1 * 10**18;
        } else if (index <= 0.0001 * 10**18) {
            return 0.9 * 10**18;
        } else if (index <= 0.001 * 10**18) {
            return 0.8 * 10**18;
        } else if (index <= 0.01 * 10**18) {
            return 0.7 * 10**18;
        } else if (index <= 0.1 * 10**18) {
            return 0.6 * 10**18;
        } else if (index <= 1 * 10**18) {
            return 0.5 * 10**18;
        } else if (index <= 5 * 10**18) {
            return 0.25 * 10**18;
        } else if (index <= 10 * 10**18) {
            return 0.1 * 10**18;
        } else if (index <= 100 * 10**18) {
            return 0.01 * 10**18;
        } else if (index <= 1000 * 10**18) {
            return 0.001 * 10**18;
        } else if (index <= 10000 * 10**18) {
            return 0.0001 * 10**18;
        } else if (index <= 100000 * 10**18) {
            return 0.00001 * 10**18;
        } else {
            return 0.000001 * 10**18;
        }
    }

    function _getInflationIndex(
        uint256 effectiveAmount,
        uint256 inflationIndex,
        uint256 blockDelta
    ) internal view returns (uint256) {
        return blockDelta * _inflationPerBlock(effectiveAmount).wadDiv(effectiveAmount) + inflationIndex;
    }

    function _getRewardsMultiplier(
        uint256 userStaked,
        uint256 lockedStake,
        uint256 totalFrozen_,
        bool isMember_
    ) internal pure returns (uint256) {
        if (isMember_) {
            if (userStaked == 0 || totalFrozen_ >= lockedStake) {
                return memberRatio;
            }

            uint256 effectiveLockedAmount = lockedStake - totalFrozen_;
            uint256 effectiveStakeAmount = userStaked - totalFrozen_;

            uint256 lendingRatio = effectiveLockedAmount.wadDiv(effectiveStakeAmount);

            return lendingRatio + memberRatio;
        } else {
            return nonMemberRatio;
        }
    }

    function _getUTokenRewardsMultiplier() internal pure returns (uint256) {
        return 10**18;
    }
}
