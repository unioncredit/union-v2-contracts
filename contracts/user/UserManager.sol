//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

import "../Controller.sol";
import "../interfaces/IAssetManager.sol";
import "../interfaces/ICreditLimitModel.sol";
import "../interfaces/IUserManager.sol";
import "../interfaces/IComptroller.sol";
import "../interfaces/IUnionToken.sol";
import "../interfaces/IDai.sol";
import "../interfaces/IUToken.sol";

/**
 * @title UserManager Contract
 * @dev Manages the Union members stake and vouches.
 */
contract UserManager is Controller, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct Vouch {
        address staker;
        uint128 amount;
        uint128 outstanding;
    }

    struct Staker {
        bool isMember;
        uint128 stakedAmount;
        uint128 outstanding;
    }

    struct FrozenInfo {
        uint256 amount;
        uint256 lastRepaid;
    }

    struct Index {
        bool isSet;
        uint256 idx;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     *  @dev Max amount that can be staked of the staking token
     */
    uint128 public maxStakeAmount;

    /**
     *  @dev The staking token that is staked in the comptroller
     */
    address public stakingToken;

    /**
     *  @dev Address of the UNION token contract
     */
    address public unionToken;

    /**
     *  @dev Address of the asset manager contract
     */
    address public assetManager;

    /**
     *  @dev uToken contract
     */
    IUToken public uToken;

    /**
     *  @dev Comptroller contract
     */
    IComptroller public comptroller;

    /**
     * @dev Number of vouches needed to become a member
     */
    uint256 public effectiveCount;

    /**
     *  @dev New member fee
     */
    uint256 public newMemberFee;

    /**
     *  @dev Total amount of staked staked token
     */
    uint256 public totalStaked;

    /**
     *  @dev Total amount of stake fozen
     */
    uint256 public totalFrozen;

    /**
     *  @dev Max blocks can be overdue for
     */
    uint256 public maxOverdue;

    /**
     *  @dev Union Stakers
     */
    mapping(address => Staker) public stakers;

    /**
     *  @dev Staker mapped to recieved vouches
     */
    mapping(address => Vouch[]) public vouchers;

    /**
     * @dev Borrower mapped to Staker mapped to index in vouch array
     */
    mapping(address => mapping(address => Index)) public voucherIndexes;

    /**
     *  @dev Mapping of member address to amount frozen
     */
    mapping(address => FrozenInfo) public memberFrozen;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error AddressZero();
    error AuthFailed();
    error ErrorSelfVouching();
    error TrustAmountTooSmall();
    error NoExistingMember();
    error NotEnoughStakers();
    error StakeLimitReached();
    error AssetManagerDepositFailed();
    error AssetManagerWithdrawFailed();
    error InsufficientBalance();
    error LockedStakeNonZero();
    error NotOverdue();
    error ExceedsLocked();
    error AmountZero();
    error OutstandingRemaining();
    error VoucherNotFound();

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    modifier onlyMember(address account) {
        if (!checkIsMember(account)) revert AuthFailed();
        _;
    }

    modifier onlyMarket() {
        if (address(uToken) != msg.sender) revert AuthFailed();
        _;
    }

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Add new member event
     *  @param member New member address
     */
    event LogAddMember(address member);

    /**
     *  @dev Update vouch for existing member event
     *  @param staker Trustee address
     *  @param borrower The address gets vouched for
     *  @param trustAmount Vouch amount
     */
    event LogUpdateTrust(address indexed staker, address indexed borrower, uint256 trustAmount);

    /**
     *  @dev New member application event
     *  @param account New member's voucher address
     *  @param borrower New member address
     */
    event LogRegisterMember(address indexed account, address indexed borrower);

    /**
     *  @dev Cancel vouching for other member event
     *  @param account New member's voucher address
     *  @param borrower The address gets vouched for
     */
    event LogCancelVouch(address indexed account, address indexed borrower);

    /**
     *  @dev Stake event
     *  @param account The staker's address
     *  @param amount The amount of tokens to stake
     */
    event LogStake(address indexed account, uint256 amount);

    /**
     *  @dev Unstake event
     *  @param account The staker's address
     *  @param amount The amount of tokens to unstake
     */
    event LogUnstake(address indexed account, uint256 amount);

    /**
     *  @dev DebtWriteOff event
     *  @param staker The staker's address
     *  @param borrower The borrower's address
     *  @param amount The amount of write off
     */
    event LogDebtWriteOff(address indexed staker, address indexed borrower, uint256 amount);

    /**
     *  @dev set utoken address
     *  @param uToken new uToken address
     */
    event LogSetUToken(address uToken);

    /**
     *  @dev set new member fee
     *  @param oldMemberFee old member fee
     *  @param newMemberFee new member fee
     */
    event LogSetNewMemberFee(uint256 oldMemberFee, uint256 newMemberFee);

    /**
     *  @dev set max stake amount
     *  @param oldMaxStakeAmount Old amount
     *  @param newMaxStakeAmount New amount
     */
    event LogSetMaxStakeAmount(uint256 oldMaxStakeAmount, uint256 newMaxStakeAmount);

    /**
     *  @dev set max overdue
     *  @param oldMaxOverdue Old value
     *  @param newMaxOverdue New value
     */
    event LogSetMaxOverdue(uint256 oldMaxOverdue, uint256 newMaxOverdue);

    /**
     *  @dev set effective count
     *  @param oldEffectiveCount Old value
     *  @param newEffectiveCount New value
     */
    event LogSetEffectiveCount(uint256 oldEffectiveCount, uint256 newEffectiveCount);

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __UserManager_init(
        address assetManager_,
        address unionToken_,
        address stakingToken_,
        address comptroller_,
        address admin_,
        uint256 maxOverdue_,
        uint256 effectiveCount_
    ) public initializer {
        Controller.__Controller_init(admin_);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        comptroller = IComptroller(comptroller_);
        assetManager = assetManager_;
        unionToken = unionToken_;
        stakingToken = stakingToken_;
        newMemberFee = 10**18; // Set the default membership fee
        maxStakeAmount = 5000e18;
        maxOverdue = maxOverdue_;
        effectiveCount = effectiveCount_;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    /**
     * @dev Set the max amount that a user can stake
     * Emits {LogSetMaxStakeAmount} event
     * @param maxStakeAmount_ The max stake amount
     */
    function setMaxStakeAmount(uint128 maxStakeAmount_) public onlyAdmin {
        uint128 oldMaxStakeAmount = maxStakeAmount;
        maxStakeAmount = maxStakeAmount_;
        emit LogSetMaxStakeAmount(uint256(oldMaxStakeAmount), uint256(maxStakeAmount));
    }

    /**
     * @dev set the UToken contract address
     * Emits {LogSetUToken} event
     * @param uToken_ UToken contract address
     */
    function setUToken(address uToken_) public onlyAdmin {
        if (uToken_ == address(0)) revert AddressZero();
        uToken = IUToken(uToken_);
        emit LogSetUToken(uToken_);
    }

    /**
     * @dev set New Member fee
     * Emits {LogSetNewMemberFee} event
     * @param amount New member fee amount
     */
    function setNewMemberFee(uint256 amount) public onlyAdmin {
        uint256 oldMemberFee = newMemberFee;
        newMemberFee = amount;
        emit LogSetNewMemberFee(oldMemberFee, amount);
    }

    /**
     * @dev set New max overdue value
     * Emits {LogSetMaxOverdue} event
     * @param _maxOverdue New maxOverdue value
     */
    function setMaxOverdue(uint256 _maxOverdue) public onlyAdmin {
        uint256 oldMaxOverdue = maxOverdue;
        maxOverdue = _maxOverdue;
        emit LogSetMaxOverdue(oldMaxOverdue, _maxOverdue);
    }

    /**
     * @dev set New effective count
     * Emits {LogSetEffectiveCount} event
     * @param _effectiveCount New effectiveCount value
     */
    function setEffectiveCount(uint256 _effectiveCount) public onlyAdmin {
        uint256 oldEffectiveCount = effectiveCount;
        effectiveCount = _effectiveCount;
        emit LogSetEffectiveCount(oldEffectiveCount, _effectiveCount);
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Check if the account is a valid member
     *  @param account Member address
     *  @return Address whether is member
     */
    function checkIsMember(address account) public view returns (bool) {
        return stakers[account].isMember;
    }

    /**
     *  @dev Get the member's available credit limit
     *  @param borrower Member address
     *  @return total Credit line amount
     */
    function getCreditLimit(address borrower) public view returns (uint256 total) {
        for (uint256 i = 0; i < vouchers[borrower].length; i++) {
            Vouch memory vouch = vouchers[borrower][i];
            Staker memory staker = stakers[vouch.staker];
            total += _min(staker.stakedAmount - staker.outstanding, vouch.amount - vouch.outstanding);
        }
    }

    /**
     *  @dev Get the count of vouchers
     *  @param borrower Address of borrower
     */
    function getVoucherCount(address borrower) public view returns (uint256) {
        return vouchers[borrower].length;
    }

    /**
     *  @dev Get the user's deposited stake amount
     *  @param account Member address
     *  @return Deposited stake amount
     */
    function getStakerBalance(address account) public view returns (uint256) {
        return stakers[account].stakedAmount;
    }

    /**
     *  @dev Get frozen coin age
     *  @param borrower Address of borrower
     *  @param pastBlocks Number of blocks past
     */
    function getFrozenCoinAge(address borrower, uint256 pastBlocks) external view returns (uint256) {
        uint256 blockDelta = block.number - memberFrozen[borrower].lastRepaid;
        return
            pastBlocks >= blockDelta
                ? memberFrozen[borrower].amount * blockDelta
                : memberFrozen[borrower].amount * pastBlocks;
    }

    /**
     *  @dev Get total frozen amount
     *  @param borrower Address of borrower
     */
    function getTotalFrozenAmount(address borrower) external view returns (uint256) {
        return memberFrozen[borrower].amount;
    }

    /**
     *  @dev Get Total locked stake
     *  @param staker Staker address
     */
    function getTotalLockedStake(address staker) external view returns (uint256) {
        return stakers[staker].outstanding;
    }

    /**
     *  @dev Get staker locked stake for a borrower
     *  @param staker Staker address
     *  @param borrower Borrower address
     *  @return LockedStake
     */
    function getLockedStake(address staker, address borrower) public view returns (uint256) {
        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) return 0;
        return vouchers[borrower][index.idx].outstanding;
    }

    /**
     *  @dev Get vouching amount
     *  @param _staker Staker address
     *  @param borrower Borrower address
     */
    function getVouchingAmount(address _staker, address borrower) public view returns (uint256) {
        Index memory index = voucherIndexes[borrower][_staker];
        Staker memory staker = stakers[_staker];
        if (!index.isSet) return 0;
        uint128 trustAmount = vouchers[borrower][index.idx].amount;
        return trustAmount < staker.stakedAmount ? trustAmount : staker.stakedAmount;
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Add member
     *  Only accepts calls from the admin
     *  Emit {LogAddMember} event
     *  @param account Member address
     */
    function addMember(address account) public onlyAdmin {
        stakers[account].isMember = true;
        emit LogAddMember(account);
    }

    /**
     *  @dev Update the trust amount for exisitng members.
     *  Emits {LogUpdateTrust} event
     *  @param borrower Account address
     *  @param trustAmount Trust amount
     */
    function updateTrust(address borrower, uint128 trustAmount) external onlyMember(msg.sender) whenNotPaused {
        if (borrower == address(0)) revert AddressZero();
        if (borrower == msg.sender) revert ErrorSelfVouching();
        Index memory index = voucherIndexes[borrower][msg.sender];
        if (index.isSet) {
            Vouch storage vouch = vouchers[borrower][index.idx];
            if (trustAmount < vouch.outstanding) revert TrustAmountTooSmall();
            vouch.amount = trustAmount;
        } else {
            voucherIndexes[borrower][msg.sender] = Index(true, vouchers[borrower].length);
            vouchers[borrower].push(Vouch(msg.sender, trustAmount, 0));
        }

        emit LogUpdateTrust(msg.sender, borrower, trustAmount);
    }

    /**
     *  @dev Remove voucher for memeber
     *  Can be called by either the borrower or the staker. It will remove the voucher from
     *  the voucher array by replacing it with the last item of the array and reseting the array
     *  size to -1 by poping off the last item
     *  Only callable by a member when the contract is not paused
     *  Emit {LogCancelVouch} event
     *  @param staker Staker address
     *  @param borrower borrower address
     */
    function cancelVouch(address staker, address borrower) external onlyMember(msg.sender) whenNotPaused {
        if (staker != msg.sender && borrower != msg.sender) revert AuthFailed();

        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) revert VoucherNotFound();

        Vouch storage vouch = vouchers[borrower][index.idx];
        if (vouch.outstanding > 0) revert LockedStakeNonZero();

        vouchers[borrower][index.idx] = vouchers[borrower][vouchers[borrower].length - 1];
        vouchers[borrower].pop();

        emit LogCancelVouch(staker, borrower);
    }

    /**
     *  @dev Apply for a membership using a signed permit
     *  @param newMember New member address
     *  @param value Amount approved by permit
     *  @param deadline Timestamp for when the permit expires
     *  @param v secp256k1 signature part
     *  @param r secp256k1 signature part
     *  @param s secp256k1 signature part
     */
    function registerMemberWithPermit(
        address newMember,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        IUnionToken unionTokenContract = IUnionToken(unionToken);
        unionTokenContract.permit(msg.sender, address(this), value, deadline, v, r, s);
        registerMember(newMember);
    }

    /**
     *  @dev Apply for membership, and burn UnionToken as application fees
     *  Emits {LogRegisterMember} event
     *  @param newMember New member address
     */
    function registerMember(address newMember) public virtual whenNotPaused {
        if (stakers[newMember].isMember) revert NoExistingMember();

        uint256 count = 0;
        uint256 vouchersLength = vouchers[newMember].length;
        for (uint256 i = 0; i < vouchersLength; i++) {
            Vouch memory vouch = vouchers[newMember][i];
            Staker memory staker = stakers[vouch.staker];
            if (staker.stakedAmount > 0) count++;
            if (count >= effectiveCount) break;
        }

        if (count < effectiveCount) revert NotEnoughStakers();

        stakers[newMember].isMember = true;
        IUnionToken(unionToken).burnFrom(msg.sender, newMemberFee);

        emit LogRegisterMember(msg.sender, newMember);
    }

    /**
     *  @dev Stake staking token to earn rewards from the comptroller
     *  Emits a {LogStake} event.
     *  @param amount Amount to stake
     */
    function stake(uint128 amount) public whenNotPaused nonReentrant {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(stakingToken);

        comptroller.withdrawRewards(msg.sender, stakingToken);

        Staker storage staker = stakers[msg.sender];

        if (staker.stakedAmount + amount > maxStakeAmount) revert StakeLimitReached();

        staker.stakedAmount += amount;
        totalStaked += amount;

        erc20Token.safeTransferFrom(msg.sender, address(this), amount);
        erc20Token.safeApprove(assetManager, 0);
        erc20Token.safeApprove(assetManager, amount);

        if (!IAssetManager(assetManager).deposit(stakingToken, amount)) revert AssetManagerDepositFailed();
        emit LogStake(msg.sender, amount);
    }

    /**
     *  @dev Unstake staking token from comptroller
     *  Emits {LogUnstake} event
     *  @param amount Amount to unstake
     */
    function unstake(uint128 amount) external whenNotPaused nonReentrant {
        Staker storage staker = stakers[msg.sender];

        if (staker.stakedAmount - staker.outstanding < amount) revert InsufficientBalance();

        comptroller.withdrawRewards(msg.sender, stakingToken);

        staker.stakedAmount -= amount;
        totalStaked -= amount;

        if (!IAssetManager(assetManager).withdraw(stakingToken, msg.sender, amount)) {
            revert AssetManagerWithdrawFailed();
        }

        emit LogUnstake(msg.sender, amount);
    }

    /**
     *  @dev collect staker rewards from the comptroller
     */
    function withdrawRewards() external whenNotPaused nonReentrant {
        comptroller.withdrawRewards(msg.sender, stakingToken);
    }

    /**
     *  @dev Write off a borrowers debt
     *  Emits {LogDebtWriteOff} event
     *  @param borrower address of borrower
     *  @param amount amount to writeoff
     */
    function debtWriteOff(
        address staker,
        address borrower,
        uint256 amount
    ) public {
        if (amount == 0) revert AmountZero();
        if (!uToken.checkIsOverdue(borrower)) revert NotOverdue();
        uint256 overdueBlocks = uToken.overdueBlocks();
        uint256 lastRepay = uToken.getLastRepay(borrower);
        if (block.number <= lastRepay + overdueBlocks + maxOverdue) {
            if (staker != msg.sender) revert AuthFailed();
        }

        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) revert VoucherNotFound();
        Vouch storage vouch = vouchers[borrower][index.idx];

        if (amount > vouch.outstanding) revert ExceedsLocked();

        // update staker staked amount
        stakers[staker].stakedAmount -= uint128(amount);
        totalStaked -= amount;

        // update frozen amounts
        uint256 frozenAmount = memberFrozen[borrower].amount;
        uint256 unFreezeAmount = amount >= frozenAmount ? frozenAmount : amount;
        memberFrozen[borrower].amount = frozenAmount - unFreezeAmount;
        totalFrozen -= unFreezeAmount;

        // update vouch trust amount
        vouch.amount -= uint128(amount);
        if (vouch.amount == 0) {
            // 3a. if trust is 0 then cancel the vouch
        }

        IAssetManager(assetManager).debtWriteOff(stakingToken, amount);
        uToken.debtWriteOff(borrower, amount);

        emit LogDebtWriteOff(msg.sender, borrower, amount);
    }

    /**
     *  @dev Borrowing from the market
     *  @param amount Borrow amount
     */
    function updateOutstanding(
        address borrower,
        uint256 amount,
        bool lock
    ) external onlyMarket {
        uint128 remaining = uint128(amount);

        for (uint256 i = 0; i < vouchers[borrower].length; i++) {
            Vouch storage vouch = vouchers[borrower][i];
            uint128 innerAmount;

            if (lock) {
                uint128 stakerOutstanding = stakers[vouch.staker].outstanding;
                uint128 stakerStakedAmount = stakers[vouch.staker].stakedAmount;
                uint128 availableStake = stakerStakedAmount - stakerOutstanding;
                uint128 borrowAmount = _min(availableStake, uint128(vouch.amount) - vouch.outstanding);
                if (borrowAmount <= 0) continue;
                innerAmount = _min(remaining, borrowAmount);
                stakers[vouch.staker].outstanding = stakerOutstanding + innerAmount;
                vouch.outstanding += innerAmount;
            } else {
                innerAmount = _min(vouch.outstanding, remaining);
                stakers[vouch.staker].outstanding -= innerAmount;
                vouch.outstanding -= innerAmount;
            }

            remaining -= innerAmount;
            if (remaining <= 0) break;
        }

        if (remaining > 0) revert OutstandingRemaining();
    }

    /**
     *  @dev Update total frozen for overdue memeber
     *  Only callable by the uToken contract
     *  @param borrower Address of borrower
     *  @param isOverdue If the borrower is overdue
     */
    function updateTotalFrozen(address borrower, bool isOverdue) external onlyMarket {
        if (isOverdue) {
            // get outstanding amount
            uint256 borrowed = uToken.getBorrowed(borrower);
            memberFrozen[borrower].amount = borrowed;
            memberFrozen[borrower].lastRepaid = uToken.getLastRepay(borrower);
            totalFrozen += borrowed;
        } else {
            // decrement totalFrozen by memberFrozen
            totalFrozen -= memberFrozen[borrower].amount;
            memberFrozen[borrower].amount = 0;
        }
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    function _min(uint128 a, uint128 b) private pure returns (uint128) {
        if (a < b) return a;
        return b;
    }
}
