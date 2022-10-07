//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Controller} from "../Controller.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {IUserManager} from "../interfaces/IUserManager.sol";
import {IComptroller} from "../interfaces/IComptroller.sol";
import {IUnionToken} from "../interfaces/IUnionToken.sol";
import {IUToken} from "../interfaces/IUToken.sol";

/**
 * @title UserManager Contract
 * @dev Manages the Union members stake and vouches.
 */
contract UserManager is Controller, IUserManager, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct Vouch {
        // staker recieveing the vouch
        address staker;
        // trust amount
        uint96 trust;
        // amount of stake locked by this vouch
        uint96 locked;
        // block number of last update
        uint64 lastUpdated;
    }

    struct Staker {
        bool isMember;
        uint96 stakedAmount;
        uint96 locked;
    }

    struct Index {
        bool isSet;
        uint128 idx;
    }

    struct Vouchee {
        address borrower;
        uint96 voucherIndex;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     *  @dev Max amount that can be staked of the staking token
     */
    uint96 public maxStakeAmount;

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
     *  @dev Total amount of stake frozen
     */
    uint256 public totalFrozen;

    /**
     *  @dev Max blocks can be overdue for
     */
    uint256 public maxOverdueBlocks;

    /**
     * @dev Max voucher limit
     */
    uint256 public maxVouchers;

    /**
     *  @dev Union Stakers
     */
    mapping(address => Staker) public stakers;

    /**
     *  @dev Staker (borrower) mapped to recieved vouches (staker)
     */
    mapping(address => Vouch[]) public vouchers;

    /**
     * @dev Borrower mapped to Staker mapped to index in vouchers array
     */
    mapping(address => mapping(address => Index)) public voucherIndexes;

    /**
     *  @dev Staker (staker) mapped to vouches given (borrower)
     */
    mapping(address => Vouchee[]) public vouchees;

    /**
     * @dev Borrower mapped to Staker mapped to index in vochee array
     */
    mapping(address => mapping(address => Index)) public voucheeIndexes;

    /**
     * @dev Stakers frozen amounts
     */
    mapping(address => uint256) public memberFrozen;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error AuthFailed();
    error ErrorSelfVouching();
    error TrustAmountLtLocked();
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
    error LockedRemaining();
    error VoucherNotFound();
    error VouchWhenOverdue();
    error MaxVouchees();
    error InvalidParams();

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
     *  @dev set max overdue blocks
     *  @param oldMaxOverdueBlocks Old value
     *  @param newMaxOverdueBlocks New value
     */
    event LogSetMaxOverdueBlocks(uint256 oldMaxOverdueBlocks, uint256 newMaxOverdueBlocks);

    /**
     *  @dev set effective count
     *  @param oldEffectiveCount Old value
     *  @param newEffectiveCount New value
     */
    event LogSetEffectiveCount(uint256 oldEffectiveCount, uint256 newEffectiveCount);

    /**
     * @dev Set max voucher
     * @param maxVouchers new max voucher limit
     */
    event LogSetMaxVouchers(uint256 maxVouchers);

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __UserManager_init(
        address assetManager_,
        address unionToken_,
        address stakingToken_,
        address comptroller_,
        address admin_,
        uint256 maxOverdueBlocks_,
        uint256 effectiveCount_,
        uint256 maxVouchers_
    ) public initializer {
        Controller.__Controller_init(admin_);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        comptroller = IComptroller(comptroller_);
        assetManager = assetManager_;
        unionToken = unionToken_;
        stakingToken = stakingToken_;
        newMemberFee = 1 ether;
        maxStakeAmount = 10_000e18;
        maxOverdueBlocks = maxOverdueBlocks_;
        effectiveCount = effectiveCount_;
        maxVouchers = maxVouchers_;
    }

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

    modifier onlyComptroller() {
        if (address(comptroller) != msg.sender) revert AuthFailed();
        _;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

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

    /**
     * @dev set the UToken contract address
     * Emits {LogSetUToken} event
     * @param uToken_ UToken contract address
     */
    function setUToken(address uToken_) external onlyAdmin {
        uToken = IUToken(uToken_);
        emit LogSetUToken(uToken_);
    }

    /**
     * @dev set New Member fee
     * @dev The amount of UNION an account must burn to become a member
     * Emits {LogSetNewMemberFee} event
     * @param amount New member fee amount
     */
    function setNewMemberFee(uint256 amount) external onlyAdmin {
        uint256 oldMemberFee = newMemberFee;
        newMemberFee = amount;
        emit LogSetNewMemberFee(oldMemberFee, amount);
    }

    /**
     * @dev set New max overdue blocks
     * Emits {LogSetMaxOverdueBlocks} event
     * @param _maxOverdueBlocks New maxOverdueBlocks value
     */
    function setMaxOverdueBlocks(uint256 _maxOverdueBlocks) external onlyAdmin {
        uint256 oldMaxOverdueBlocks = maxOverdueBlocks;
        maxOverdueBlocks = _maxOverdueBlocks;
        emit LogSetMaxOverdueBlocks(oldMaxOverdueBlocks, _maxOverdueBlocks);
    }

    /**
     * @dev set New effective count
     * @dev this is the number of vouches an account needs in order
     *      to register as a member
     * Emits {LogSetEffectiveCount} event
     * @param _effectiveCount New effectiveCount value
     */
    function setEffectiveCount(uint256 _effectiveCount) external onlyAdmin {
        uint256 oldEffectiveCount = effectiveCount;
        effectiveCount = _effectiveCount;
        emit LogSetEffectiveCount(oldEffectiveCount, _effectiveCount);
    }

    function setMaxVouchers(uint256 _maxVouchers) external onlyAdmin {
        maxVouchers = _maxVouchers;
        emit LogSetMaxVouchers(_maxVouchers);
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
     *  @dev  Get the member's available credit limit
     *  @dev  IMPORTANT: This function can take up a tonne of gas as the vouchers[address] array
     *        grows in size. the maxVoucher limit will ensure this function can always run within a
     *        single block but it is intended only to be used as a view function called from a UI
     *  @param borrower Member address
     *  @return total Credit line amount
     */
    function getCreditLimit(address borrower) external view returns (uint256 total) {
        for (uint256 i = 0; i < vouchers[borrower].length; i++) {
            Vouch memory vouch = vouchers[borrower][i];
            Staker memory staker = stakers[vouch.staker];
            total += _min(staker.stakedAmount - staker.locked, vouch.trust - vouch.locked);
        }
    }

    /**
     *  @dev  Get the count of vouchers
     *        Vouchers are addresses that this borrower is recieving a vouch from.
     *  @param borrower Address of borrower
     */
    function getVoucherCount(address borrower) external view returns (uint256) {
        return vouchers[borrower].length;
    }

    /**
     *  @dev  Get the count of vouchees
     *        Voucheers are addresses that this staker is vouching for
     *  @param staker Address of staker
     */
    function getVoucheeCount(address staker) external view returns (uint256) {
        return vouchees[staker].length;
    }

    /**
     *  @dev Get the user's deposited stake amount
     *  @param account Member address
     *  @return Deposited stake amount
     */
    function getStakerBalance(address account) external view returns (uint256) {
        return stakers[account].stakedAmount;
    }

    /**
     *  @dev Get frozen coin age
     *  @param  staker Address of staker
     *  @param  pastBlocks Number of blocks past to calculate coin age from
     *          coin age = min(block.number - lastUpdated, pastBlocks) * amount
     */
    function getFrozenInfo(address staker, uint256 pastBlocks)
        public
        view
        returns (uint256 memberTotalFrozen, uint256 memberFrozenCoinAge)
    {
        uint256 overdueBlocks = uToken.overdueBlocks();
        uint256 voucheesLength = vouchees[staker].length;
        // Loop through all of the stakers vouchees sum their total
        // locked balance and sum their total memberFrozenCoinAge
        for (uint256 i = 0; i < voucheesLength; i++) {
            // Get the vouchee record and look up the borrowers voucher record
            // to get the locked amount and lastUpdate block number
            Vouchee memory vouchee = vouchees[staker][i];
            Vouch memory vouch = vouchers[vouchee.borrower][vouchee.voucherIndex];

            uint256 lastUpdated = vouch.lastUpdated;
            uint256 diff = block.number - lastUpdated;

            if (overdueBlocks < diff) {
                uint96 locked = vouch.locked;
                memberTotalFrozen += locked;
                if (pastBlocks >= diff) {
                    memberFrozenCoinAge += (locked * diff);
                } else {
                    memberFrozenCoinAge += (locked * pastBlocks);
                }
            }
        }
    }

    /**
     *  @dev Get Total locked stake
     *  @param staker Staker address
     */
    function getTotalLockedStake(address staker) external view returns (uint256) {
        return stakers[staker].locked;
    }

    /**
     *  @dev Get staker locked stake for a borrower
     *  @param staker Staker address
     *  @param borrower Borrower address
     *  @return LockedStake
     */
    function getLockedStake(address staker, address borrower) external view returns (uint256) {
        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) return 0;
        return vouchers[borrower][index.idx].locked;
    }

    /**
     *  @dev Get vouching amount
     *  @param _staker Staker address
     *  @param borrower Borrower address
     */
    function getVouchingAmount(address _staker, address borrower) external view returns (uint256) {
        Index memory index = voucherIndexes[borrower][_staker];
        Staker memory staker = stakers[_staker];
        if (!index.isSet) return 0;
        uint96 trustAmount = vouchers[borrower][index.idx].trust;
        return trustAmount < staker.stakedAmount ? trustAmount : staker.stakedAmount;
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Manually add union members and bypass all the requirements of `registerMember`
     *  Only accepts calls from the admin
     *  Emit {LogAddMember} event
     *  @param account Member address
     */
    function addMember(address account) external onlyAdmin {
        stakers[account].isMember = true;
        emit LogAddMember(account);
    }

    /**
     *  @dev  Update the trust amount for exisitng members.
     *  @dev  Trust is the amount of the underlying token you would in theory be
     *        happy to lend to another member. Vouch is derived from trust and stake.
     *        Vouch is the minimum of trust and staked amount.
     *  Emits {LogUpdateTrust} event
     *  @param borrower Account address
     *  @param trustAmount Trust amount
     */
    function updateTrust(address borrower, uint96 trustAmount) external onlyMember(msg.sender) whenNotPaused {
        address staker = msg.sender;
        if (borrower == staker) revert ErrorSelfVouching();
        if (!checkIsMember(staker)) revert AuthFailed();

        // Check if this staker is already vouching for this borrower
        // If they are already vouching then update the existing vouch record
        // If this is a new vouch then insert a new Vouch record
        Index memory index = voucherIndexes[borrower][staker];
        if (index.isSet) {
            // Update existing record checking that the new trust amount is
            // not less than the amount of stake currently locked by the borrower
            Vouch storage vouch = vouchers[borrower][index.idx];
            if (trustAmount < vouch.locked) revert TrustAmountLtLocked();
            vouch.trust = trustAmount;
        } else {
            // If the member is overdue they cannot create new vouches they can
            // only update existing vouches
            if (uToken.checkIsOverdue(staker)) revert VouchWhenOverdue();

            // This is a new vouch so we need to check that the
            // member has not reached the max voucher limit
            uint256 voucheesLength = vouchees[staker].length;
            if (voucheesLength >= maxVouchers) revert MaxVouchees();

            // Get the new index that this vouch is going to be inserted at
            // Then update the voucher indexes for this borrower as well as
            // Adding the Vouch the the vouchers array for this staker
            uint256 voucherIndex = vouchers[borrower].length;
            voucherIndexes[borrower][staker] = Index(true, uint128(voucherIndex));
            vouchers[borrower].push(Vouch(staker, trustAmount, 0, 0));

            // Add the voucherIndex of this new vouch to the vouchees array for this
            // staker then update the voucheeIndexes with the voucheeIndex
            uint256 voucheeIndex = voucheesLength;
            vouchees[staker].push(Vouchee(borrower, uint96(voucherIndex)));
            voucheeIndexes[borrower][staker] = Index(true, uint128(voucheeIndex));
        }

        emit LogUpdateTrust(staker, borrower, trustAmount);
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
    function cancelVouch(address staker, address borrower) public onlyMember(msg.sender) whenNotPaused {
        if (staker != msg.sender && borrower != msg.sender) revert AuthFailed();

        Index memory voucherIndex = voucherIndexes[borrower][staker];
        if (!voucherIndex.isSet) revert VoucherNotFound();

        // Check that the locked amount for this vouch is 0
        Vouch memory vouch = vouchers[borrower][voucherIndex.idx];
        if (vouch.locked > 0) revert LockedStakeNonZero();

        // Remove borrower from vouchers array by moving the last item into the position
        // of the index being removed and then poping the last item off the array
        vouchers[borrower][voucherIndex.idx] = vouchers[borrower][vouchers[borrower].length - 1];
        vouchers[borrower].pop();
        delete voucherIndexes[borrower][staker];

        // Remove borrower from vouchee array by moving the last item into the position
        // of the index being removed and then poping the last item off the array
        Index memory voucheeIndex = voucheeIndexes[borrower][staker];
        vouchees[staker][voucheeIndex.idx] = vouchees[staker][vouchees[staker].length - 1];
        vouchees[staker].pop();
        delete voucheeIndexes[borrower][staker];

        emit LogCancelVouch(staker, borrower);
    }

    /**
     *  @notice Register a a member using a signed permit
     *  @dev See registerMember
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
    ) external whenNotPaused {
        IUnionToken unionTokenContract = IUnionToken(unionToken);
        unionTokenContract.permit(msg.sender, address(this), value, deadline, v, r, s);
        registerMember(newMember);
    }

    /**
     *  @notice Register a a member, and burn an application fees
     *  @dev    In order to register as a member an address must be recieving x amount
     *          of vouches greater than 0 from stakers. x is defined by `effectiveCount`
     *          Emits {LogRegisterMember} event
     *  @param newMember New member address
     */
    function registerMember(address newMember) public virtual whenNotPaused {
        if (stakers[newMember].isMember) revert NoExistingMember();

        uint256 count = 0;
        uint256 vouchersLength = vouchers[newMember].length;

        // Loop through all the vouchers to count how many active vouches there
        // are that are greater than 0. Vouch is the min of stake and trust
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
     *  @notice Stake staking tokens
     *  @dev    Stake is used to underwrite loans and becomes locked if a
     *          member a staker has vouched for borrows against it.
     *          Stake also earns rewards from the comptroller
     *  Emits a {LogStake} event.
     *  @param amount Amount to stake
     */
    function stake(uint96 amount) public whenNotPaused nonReentrant {
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
     *  @notice Unstake staking token
     *  @dev    Tokens can only be unstaked if they are not locked. ie a
     *          vouchee is not borrowing against them.
     *  Emits {LogUnstake} event
     *  @param amount Amount to unstake
     */
    function unstake(uint96 amount) external whenNotPaused nonReentrant {
        Staker storage staker = stakers[msg.sender];

        // Stakers can only unstaked stake balance that is unlocked. Stake balance
        // becomes locked when it is used to underwrite a borrow.
        if (staker.stakedAmount - staker.locked < amount) revert InsufficientBalance();

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
     *  @notice Write off a borrowers debt
     *  @dev    Used the stakers locked stake to write off the loan, transfering the
     *          Stake to the AssetManager and adjusting balances in the AssetManager
     *          and the UToken to repay the principal
     *  @dev    Emits {LogDebtWriteOff} event
     *  @param borrower address of borrower
     *  @param amount amount to writeoff
     */
    function debtWriteOff(
        address staker,
        address borrower,
        uint96 amount
    ) external {
        if (amount == 0) revert AmountZero();
        uint256 overdueBlocks = uToken.overdueBlocks();
        uint256 lastRepay = uToken.getLastRepay(borrower);

        // This function is only callable by the public if the loan is overdue by
        // overdue blocks + maxOverdueBlocks. This stops the system being left with
        // debt that is overdue indefinitely and no ability to do anything about it.
        if (block.number <= lastRepay + overdueBlocks + maxOverdueBlocks) {
            if (staker != msg.sender) revert AuthFailed();
        }

        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) revert VoucherNotFound();
        Vouch storage vouch = vouchers[borrower][index.idx];

        if (amount > vouch.locked) revert ExceedsLocked();

        // update staker staked amount
        stakers[staker].stakedAmount -= amount;
        stakers[staker].locked -= amount;
        totalStaked -= amount;

        // update vouch trust amount
        vouch.trust -= amount;
        vouch.locked -= amount;

        // Update total frozen and member frozen. We don't want to move th
        // burden of calling updateFrozenInfo into this function as it is quite
        // gas intensive. Instead we just want to remove the amount that was
        // frozen which is now being written off. However, it is possible that
        // member frozen has not been updated prior to calling debtWriteOff and
        // the amount being written off could be greater than the amount frozen.
        // To avoid an underflow here we need to check this condition
        uint256 stakerFrozen = memberFrozen[staker];
        if (amount > stakerFrozen) {
            // The amount being written off is more than the amount that has
            // been previously frozen for this staker. Reset their frozen stake
            // to zero and adjust totalFrozen
            memberFrozen[staker] = 0;
            totalFrozen -= stakerFrozen;
        } else {
            totalFrozen -= amount;
            memberFrozen[staker] -= amount;
        }

        if (vouch.trust == 0) {
            cancelVouch(staker, borrower);
        }

        // Notify the AssetManager and the UToken market of the debt write off
        // so they can adjust their balances accordingly
        IAssetManager(assetManager).debtWriteOff(stakingToken, uint256(amount));
        uToken.debtWriteOff(borrower, uint256(amount));

        comptroller.updateTotalStaked(stakingToken, totalStaked - totalFrozen);

        emit LogDebtWriteOff(msg.sender, borrower, uint256(amount));
    }

    /**
     *  @notice Borrowing from the market
     *  @dev    Locks/Unlocks the borrowers stakers staked amounts in a first in
     *          First out order. Meaning the members that vouched for this borrower
     *          first will be the first members to get their stake locked or unlocked
     *          following a borrow or repayment.
     *  @param borrower The address of the borrower
     *  @param amount Lock/Unlock amount
     *  @param lock If the amount is being locked or unlocked
     */
    function updateLocked(
        address borrower,
        uint96 amount,
        bool lock
    ) external onlyMarket {
        uint96 remaining = amount;

        for (uint256 i = 0; i < vouchers[borrower].length; i++) {
            Vouch storage vouch = vouchers[borrower][i];
            uint96 innerAmount;

            if (lock) {
                // Look up the staker and determine how much unlock stake they
                // have available for the borrower to borrow. If there is 0
                // then continue to the next voucher in the array
                uint96 stakerLocked = stakers[vouch.staker].locked;
                uint96 stakerStakedAmount = stakers[vouch.staker].stakedAmount;
                uint96 availableStake = stakerStakedAmount - stakerLocked;
                uint96 lockAmount = _min(availableStake, vouch.trust - vouch.locked);
                if (lockAmount == 0) continue;

                // Calculate the amount to add to the lock then
                // add the extra amount to lock to the stakers locked amount
                // and also update the vouches locked amount and lastUpdated block
                innerAmount = _min(remaining, lockAmount);
                stakers[vouch.staker].locked = stakerLocked + innerAmount;
                vouch.locked += innerAmount;
                vouch.lastUpdated = uint64(block.number);
            } else {
                // Look up how much this vouch has locked. If it is 0 then
                // continue to the next voucher. Then calculate the amount to
                // unlock which is the min of the vouches lock and what is
                // remaining to unlock
                uint96 locked = vouch.locked;
                if (locked == 0) continue;
                innerAmount = _min(locked, remaining);

                // Update the stored locked values and last updated block
                stakers[vouch.staker].locked -= innerAmount;
                vouch.locked -= innerAmount;
                vouch.lastUpdated = uint64(block.number);
            }

            remaining -= innerAmount;
            // If there is no remaining amount to lock/unlock
            // we can stop looping through vouchers
            if (remaining <= 0) break;
        }

        // If we have looped through all the available vouchers for this
        // borrower and we still have a remaining amount then we have to
        // revert as there is not enough vouchers to lock/unlock
        if (remaining > 0) revert LockedRemaining();
    }

    /**
     * @dev Update the frozen info for a single staker
     * @param staker Staker address
     * @param pastBlocks The past blocks
     * @return  memberTotalFrozen Total frozen amount for this staker
     *          memberFrozenCoinAge Total frozen coin age for this staker
     */
    function _updateFrozen(address staker, uint256 pastBlocks) internal returns (uint256, uint256) {
        (uint256 memberTotalFrozen, uint256 memberFrozenCoinAge) = getFrozenInfo(staker, pastBlocks);

        uint256 memberFrozenBefore = memberFrozen[staker];
        if (memberFrozenBefore != memberTotalFrozen) {
            memberFrozen[staker] = memberTotalFrozen;
            totalFrozen = totalFrozen - memberFrozenBefore + memberTotalFrozen;
        }

        return (memberTotalFrozen, memberFrozenCoinAge);
    }

    /**
     * @dev Update the frozen info by the comptroller
     * @param staker Staker address
     * @param pastBlocks The past blocks
     * @return  memberTotalFrozen Total frozen amount for this staker
     *          memberFrozenCoinAge Total frozen coin age for this staker
     */
    function updateFrozenInfo(address staker, uint256 pastBlocks) external onlyComptroller returns (uint256, uint256) {
        return _updateFrozen(staker, pastBlocks);
    }

    /**
     * @dev Update the frozen info for external scripts
     * @param stakers Stakers address
     */
    function batchUpdateFrozenInfo(address[] calldata stakers) external whenNotPaused {
        uint256 stakerLength = stakers.length;
        if (stakerLength == 0) revert InvalidParams();

        for (uint256 i = 0; i < stakerLength; i++) {
            _updateFrozen(stakers[i], 0);
        }
        comptroller.updateTotalStaked(stakingToken, totalStaked - totalFrozen);
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    function _min(uint96 a, uint96 b) private pure returns (uint96) {
        if (a < b) return a;
        return b;
    }
}
