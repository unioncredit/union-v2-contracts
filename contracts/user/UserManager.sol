//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

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
        // staker recieveing the vouch
        address staker;
        // trust amount
        uint96 amount;
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
     *  TODO: add back update total frozen function
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
    mapping(address => bytes32[]) public vouchees;

    /**
     * @dev Borrower mapped to Staker mapped to index in vochee array
     */
    mapping(address => mapping(address => Index)) public voucheeIndexes;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error AddressZero();
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
        maxStakeAmount = 10_000e18;
        maxOverdue = maxOverdue_;
        effectiveCount = effectiveCount_;
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

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    /**
     * @dev Set the max amount that a user can stake
     * Emits {LogSetMaxStakeAmount} event
     * @param maxStakeAmount_ The max stake amount
     */
    function setMaxStakeAmount(uint96 maxStakeAmount_) public onlyAdmin {
        uint96 oldMaxStakeAmount = maxStakeAmount;
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
     * @dev The amount of UNION an account must burn to become a member
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
     * @dev this is the number of vouches an account needs in order
     *      to register as a member
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
            total += _min(staker.stakedAmount - staker.locked, vouch.amount - vouch.locked);
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
     *  @param  staker Address of staker
     *  @param  pastBlocks Number of blocks past to calculate coinAge from
     *          coinage = min(block.number - lastUpdated, pastBlocks) * amount
     */
    function getFrozenInfo(address staker, uint256 pastBlocks)
        external
        view
        returns (uint256 totalFrozen, uint256 frozenCoinage)
    {
        uint256 overdueBlocks = uToken.overdueBlocks();
        uint256 voucheesLength = vouchees[staker].length;
        // Loop through all of the stakers vouchees sum their total
        // locked balance and sum their total frozenCoinage
        for (uint256 i = 0; i < voucheesLength; i++) {
            // Get the vouchee record and look up the borrowers voucher record
            // to get the locked amount and lastUpdate block number
            (address borrower, uint96 voucherIndex) = _vouchee(vouchees[staker][i]);
            Vouch memory vouch = vouchers[borrower][voucherIndex];

            uint256 lastUpdated = vouch.lastUpdated;
            uint256 diff = block.number - lastUpdated;

            if (overdueBlocks < diff) {
                uint96 locked = vouch.locked;
                totalFrozen += locked;
                if (pastBlocks >= diff) {
                    frozenCoinage += (locked * diff);
                } else {
                    frozenCoinage += (locked * pastBlocks);
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
    function getLockedStake(address staker, address borrower) public view returns (uint256) {
        Index memory index = voucherIndexes[borrower][staker];
        if (!index.isSet) return 0;
        return vouchers[borrower][index.idx].locked;
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
        uint96 trustAmount = vouchers[borrower][index.idx].amount;
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
            vouch.amount = trustAmount;
        } else {
            // Get the new index that this vouch is going to be inserted at
            // Then update the voucher indexes for this borrower as well as
            // Adding the Vouch the the vouchers array for this staker
            uint256 voucherIndex = vouchers[borrower].length;
            voucherIndexes[borrower][staker] = Index(true, uint128(voucherIndex));
            vouchers[borrower].push(Vouch(staker, trustAmount, 0, 0));

            // Add the voucherIndex of this new vouch to the vouchees array for this
            // staker then update the voucheeIndexes with the voucheeIndex
            uint256 voucheeIndex = vouchees[staker].length;
            vouchees[staker].push(_vouchee(borrower, uint96(voucherIndex)));
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

        // Remove borrower from vouchers array
        vouchers[borrower][voucherIndex.idx] = vouchers[borrower][vouchers[borrower].length - 1];
        vouchers[borrower].pop();
        delete voucherIndexes[borrower][staker];

        // Remove borrower from vouchee array
        Index memory voucheeIndex = voucheeIndexes[borrower][staker];
        vouchees[staker][voucheeIndex.idx] = vouchees[staker][vouchees[staker].length - 1];
        vouchees[staker].pop();
        delete voucheeIndexes[borrower][staker];

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
     *  @dev Unstake staking token from comptroller
     *  Emits {LogUnstake} event
     *  @param amount Amount to unstake
     */
    function unstake(uint96 amount) external whenNotPaused nonReentrant {
        Staker storage staker = stakers[msg.sender];
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
     *  @dev Write off a borrowers debt
     *  Emits {LogDebtWriteOff} event
     *  @param borrower address of borrower
     *  @param amount amount to writeoff
     */
    function debtWriteOff(
        address staker,
        address borrower,
        uint96 amount
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

        if (amount > vouch.locked) revert ExceedsLocked();

        // update staker staked amount
        stakers[staker].stakedAmount -= amount;
        totalStaked -= amount;

        // update vouch trust amount
        vouch.lastUpdated = uint64(block.number);
        vouch.amount -= amount;
        if (vouch.amount == 0) {
            cancelVouch(staker, borrower);
        }

        IAssetManager(assetManager).debtWriteOff(stakingToken, uint256(amount));
        uToken.debtWriteOff(borrower, uint256(amount));

        emit LogDebtWriteOff(msg.sender, borrower, uint256(amount));
    }

    /**
     *  @dev Borrowing from the market
     *  @param amount Borrow amount
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
                uint96 lockAmount = _min(availableStake, vouch.amount - vouch.locked);
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

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    function _min(uint96 a, uint96 b) private pure returns (uint96) {
        if (a < b) return a;
        return b;
    }

    function _vouchee(address addr, uint96 n) private pure returns (bytes32) {
        return bytes32(abi.encodePacked(addr, n));
    }

    function _vouchee(bytes32 b) private pure returns (address addr, uint96 n) {
        addr = address(bytes20(b));
        n = uint96(bytes12(bytes20(uint160(2**160 - 1)) & (b << 160)));
    }
}
