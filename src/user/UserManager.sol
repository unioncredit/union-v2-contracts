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
 * @dev Manages the Union members credit lines, and their vouchees and borrowers info.
 */
contract UserManager is Controller, IUserManager, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Member {
        bool isMember;
        CreditLine creditLine;
    }

    //address: member address, uint256: trustAmount
    struct CreditLine {
        mapping(address => uint256) borrowers;
        address[] borrowerAddresses;
        mapping(address => uint256) stakers;
        address[] stakerAddresses;
        mapping(address => uint256) lockedAmount;
    }

    struct TrustInfo {
        address[] stakerAddresses;
        address[] borrowerAddresses;
        uint256 effectiveCount;
        address staker;
        uint256 vouchingAmount;
        uint256 stakingAmount;
        uint256 availableStakingAmount;
        uint256 lockedStake;
        uint256 totalLockedStake;
    }

    /**
     *  @dev Max amount that can be staked of the staking token
     */
    uint256 public maxStakeAmount;

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
     *  @dev Credit Limit Model contract
     */
    ICreditLimitModel public creditLimitModel;

    /**
     *  @dev Comptroller contract
     */
    IComptroller public comptroller;

    /**
     *  @dev New member fee
     */
    uint256 public newMemberFee;

    /**
     *  @dev Total amount of staked staked token
     */
    // slither-disable-next-line constable-states
    uint256 public override totalStaked;

    /**
     *  @dev Total frozen
     */
    // slither-disable-next-line constable-states
    uint256 public override totalFrozen;

    /**
     *  @dev Union members
     */
    mapping(address => Member) internal members;

    /**
     *  @dev Mapping of stakers to staking amount
     */
    // slither-disable-next-line uninitialized-state
    mapping(address => uint256) public stakers;

    /**
     *  @dev Mapping of member address to amount frozen
     */
    mapping(address => uint256) public memberFrozen;

    error AddressZero();
    error AmountZero();
    error ErrorData();
    error AuthFailed();
    error NotCreditLimitModel();
    error ErrorSelfVouching();
    error MaxTrustLimitReached();
    error TrustAmountTooLarge();
    error LockedStakeNonZero();
    error NoExistingMember();
    error NotEnoughStakers();
    error StakeLimitReached();
    error AssetManagerDepositFailed();
    error AssetManagerWithdrawFailed();
    error InsufficientBalance();
    error ExceedsTotalStaked();
    error NotOverdue();
    error ExceedsLocked();
    error ExceedsTotalFrozen();
    error LengthNotMatch();
    error ErrorTotalStake();

    modifier onlyMember(address account) {
        if (!checkIsMember(account)) revert AuthFailed();
        _;
    }

    modifier onlyMarketOrAdmin() {
        if (address(uToken) != msg.sender && !isAdmin(msg.sender)) revert AuthFailed();
        _;
    }

    /**
     *  @dev Update new credit limit model event
     *  @param newCreditLimitModel New credit limit model address
     */
    event LogNewCreditLimitModel(address newCreditLimitModel);

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

    event LogSetMaxStakeAmount(uint256 oldMaxStakeAmount, uint256 newMaxStakeAmount);

    function __UserManager_init(
        address assetManager_,
        address unionToken_,
        address stakingToken_,
        address creditLimitModel_,
        address comptroller_,
        address admin_
    ) public initializer {
        Controller.__Controller_init(admin_);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        _setCreditLimitModel(creditLimitModel_);
        comptroller = IComptroller(comptroller_);
        assetManager = assetManager_;
        unionToken = unionToken_;
        stakingToken = stakingToken_;
        newMemberFee = 10**18; // Set the default membership fee
        maxStakeAmount = 5000e18;
    }

    /**
     * @dev Set the max amount that a user can stake
     * Emits {LogSetMaxStakeAmount} event
     * @param maxStakeAmount_ The max stake amount
     */
    function setMaxStakeAmount(uint256 maxStakeAmount_) public onlyAdmin {
        uint256 oldMaxStakeAmount = maxStakeAmount;
        maxStakeAmount = maxStakeAmount_;
        emit LogSetMaxStakeAmount(oldMaxStakeAmount, maxStakeAmount);
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
        emit LogSetNewMemberFee(oldMemberFee, newMemberFee);
    }

    /**
     *  @dev Change the credit limit model
     *  Only accepts calls from the admin
     *  @param newCreditLimitModel New credit limit model address
     */
    function setCreditLimitModel(address newCreditLimitModel) public override onlyAdmin {
        if (newCreditLimitModel == address(0)) revert AddressZero();
        _setCreditLimitModel(newCreditLimitModel);
    }

    function _setCreditLimitModel(address newCreditLimitModel) private {
        if (!ICreditLimitModel(newCreditLimitModel).isCreditLimitModel()) revert NotCreditLimitModel();

        creditLimitModel = ICreditLimitModel(newCreditLimitModel);

        emit LogNewCreditLimitModel(newCreditLimitModel);
    }

    /**
     *  @dev Check if the account is a valid member
     *  @param account Member address
     *  @return Address whether is member
     */
    function checkIsMember(address account) public view override returns (bool) {
        return members[account].isMember;
    }

    /**
     *  @dev Get member borrowerAddresses
     *  @param account Member address
     *  @return Address array
     */
    function getBorrowerAddresses(address account) public view override returns (address[] memory) {
        return members[account].creditLine.borrowerAddresses;
    }

    /**
     *  @dev Get member stakerAddresses
     *  @param account Member address
     *  @return Address array
     */
    function getStakerAddresses(address account) public view override returns (address[] memory) {
        return members[account].creditLine.stakerAddresses;
    }

    /**
     *  @dev Get member backer asset
     *  @param account Member address
     *  @param borrower Borrower address
     *  @return trustAmount vouchingAmount lockedStake. Trust amount, vouch amount, and locked stake amount
     */
    function getBorrowerAsset(address account, address borrower)
        public
        view
        override
        returns (
            uint256 trustAmount,
            uint256 vouchingAmount,
            uint256 lockedStake
        )
    {
        trustAmount = members[account].creditLine.borrowers[borrower];
        lockedStake = getLockedStake(account, borrower);
        vouchingAmount = getVouchingAmount(account, borrower);
    }

    /**
     *  @dev Get member stakers asset
     *  @param account Member address
     *  @param staker Staker address
     *  @return trustAmount lockedStake vouchingAmount. Vouch amount and lockedStake
     */
    function getStakerAsset(address account, address staker)
        public
        view
        override
        returns (
            uint256 trustAmount,
            uint256 vouchingAmount,
            uint256 lockedStake
        )
    {
        trustAmount = members[account].creditLine.stakers[staker];
        lockedStake = getLockedStake(staker, account);
        vouchingAmount = getVouchingAmount(staker, account);
    }

    /**
     *  @dev Get staker locked stake for a borrower
     *  @param staker Staker address
     *  @param borrower Borrower address
     *  @return LockedStake
     */
    function getLockedStake(address staker, address borrower) public view returns (uint256) {
        return members[staker].creditLine.lockedAmount[borrower];
    }

    /**
     *  @dev Get the user's locked stake from all his backed loans
     *  @param staker Staker address
     *  @return LockedStake
     */
    function getTotalLockedStake(address staker) public view override returns (uint256) {
        uint256 totalLockedStake = 0;
        uint256 stakingAmount = stakers[staker];
        address[] memory borrowerAddresses = members[staker].creditLine.borrowerAddresses;
        address borrower;
        uint256 addressesLength = borrowerAddresses.length;
        for (uint256 i = 0; i < addressesLength; i++) {
            borrower = borrowerAddresses[i];
            totalLockedStake += getLockedStake(staker, borrower);
        }

        if (stakingAmount >= totalLockedStake) {
            return totalLockedStake;
        } else {
            return stakingAmount;
        }
    }

    /**
     *  @dev Get staker's defaulted / frozen staked token amount
     *  @param staker Staker address
     *  @return Frozen token amount
     */
    function getTotalFrozenAmount(address staker) public view override returns (uint256) {
        TrustInfo memory trustInfo;
        uint256 totalFrozenAmount = 0;
        trustInfo.borrowerAddresses = members[staker].creditLine.borrowerAddresses;
        trustInfo.stakingAmount = stakers[staker];

        address borrower;
        uint256 addressLength = trustInfo.borrowerAddresses.length;
        for (uint256 i = 0; i < addressLength; i++) {
            borrower = trustInfo.borrowerAddresses[i];
            if (uToken.checkIsOverdue(borrower)) {
                totalFrozenAmount += getLockedStake(staker, borrower);
            }
        }

        if (trustInfo.stakingAmount >= totalFrozenAmount) {
            return totalFrozenAmount;
        } else {
            return trustInfo.stakingAmount;
        }
    }

    /**
     *  @dev Get the member's available credit line
     *  @param borrower Member address
     *  @return Credit line amount
     */
    function getCreditLimit(address borrower) public view override returns (int256) {
        TrustInfo memory trustInfo;
        trustInfo.stakerAddresses = members[borrower].creditLine.stakerAddresses;
        // Get the number of effective vouchee, first
        trustInfo.effectiveCount = 0;
        uint256 stakerAddressesLength = trustInfo.stakerAddresses.length;
        uint256[] memory limits = new uint256[](stakerAddressesLength);

        for (uint256 i = 0; i < stakerAddressesLength; i++) {
            trustInfo.staker = trustInfo.stakerAddresses[i];

            trustInfo.stakingAmount = stakers[trustInfo.staker];

            trustInfo.vouchingAmount = getVouchingAmount(trustInfo.staker, borrower);

            //A vouchingAmount value of 0 means that the amount of stake is 0 or trust is 0. In this case, this data is not used to calculate the credit limit
            if (trustInfo.vouchingAmount > 0) {
                //availableStakingAmount is staker‘s free stake amount
                trustInfo.borrowerAddresses = getBorrowerAddresses(trustInfo.staker);

                trustInfo.availableStakingAmount = trustInfo.stakingAmount;
                uint256 totalLockedStake = getTotalLockedStake(trustInfo.staker);
                if (trustInfo.stakingAmount <= totalLockedStake) {
                    trustInfo.availableStakingAmount = 0;
                } else {
                    trustInfo.availableStakingAmount = trustInfo.stakingAmount - totalLockedStake;
                }

                trustInfo.lockedStake = getLockedStake(trustInfo.staker, borrower);

                if (trustInfo.vouchingAmount < trustInfo.lockedStake) revert ErrorData();

                //The actual effective guarantee amount cannot exceed availableStakingAmount,
                if (trustInfo.vouchingAmount >= trustInfo.availableStakingAmount + trustInfo.lockedStake) {
                    limits[trustInfo.effectiveCount] = trustInfo.availableStakingAmount;
                } else {
                    if (trustInfo.vouchingAmount <= trustInfo.lockedStake) {
                        limits[trustInfo.effectiveCount] = 0;
                    } else {
                        limits[trustInfo.effectiveCount] = trustInfo.vouchingAmount - trustInfo.lockedStake;
                    }
                }
                trustInfo.effectiveCount += 1;
            }
        }

        uint256[] memory creditlimits = new uint256[](trustInfo.effectiveCount);
        for (uint256 j = 0; j < trustInfo.effectiveCount; j++) {
            creditlimits[j] = limits[j];
        }

        return int256(creditLimitModel.getCreditLimit(creditlimits)) - int256(uToken.calculatingInterest(borrower));
    }

    /**
     *  @dev Get vouching amount
     *  @param staker Staker address
     *  @param borrower Borrower address
     */
    function getVouchingAmount(address staker, address borrower) public view returns (uint256) {
        uint256 totalStake = stakers[staker];
        uint256 trustAmount = members[borrower].creditLine.stakers[staker];
        return trustAmount > totalStake ? totalStake : trustAmount;
    }

    /**
     *  @dev Get the user's deposited stake amount
     *  @param account Member address
     *  @return Deposited stake amount
     */
    function getStakerBalance(address account) public view override returns (uint256) {
        return stakers[account];
    }

    /**
     *  @dev Add member
     *  Only accepts calls from the admin
     *  Emit {LogAddMember} event
     *  @param account Member address
     */
    function addMember(address account) public override onlyAdmin {
        members[account].isMember = true;
        emit LogAddMember(account);
    }

    /**
     *  @dev Update the trust amount for exisitng members.
     *  Emits {LogUpdateTrust} event
     *  @param borrower_ Account address
     *  @param trustAmount Trust amount
     */
    function updateTrust(address borrower_, uint256 trustAmount)
        external
        override
        onlyMember(msg.sender)
        whenNotPaused
    {
        if (borrower_ == address(0)) revert AddressZero();
        address borrower = borrower_;

        TrustInfo memory trustInfo;
        trustInfo.staker = msg.sender;
        if (trustInfo.staker == borrower) revert ErrorSelfVouching();
        if (
            members[borrower].creditLine.stakerAddresses.length >= _maxTrust() ||
            members[trustInfo.staker].creditLine.borrowerAddresses.length >= _maxTrust()
        ) revert MaxTrustLimitReached();
        trustInfo.borrowerAddresses = members[trustInfo.staker].creditLine.borrowerAddresses;
        trustInfo.stakerAddresses = members[borrower].creditLine.stakerAddresses;
        trustInfo.lockedStake = getLockedStake(trustInfo.staker, borrower);

        if (trustAmount < trustInfo.lockedStake) revert TrustAmountTooLarge();
        uint256 borrowerCount = members[trustInfo.staker].creditLine.borrowerAddresses.length;
        bool borrowerExist = false;
        for (uint256 i = 0; i < borrowerCount; i++) {
            if (trustInfo.borrowerAddresses[i] == borrower) {
                borrowerExist = true;
                break;
            }
        }

        uint256 stakerCount = members[borrower].creditLine.stakerAddresses.length;
        bool stakerExist = false;
        for (uint256 i = 0; i < stakerCount; i++) {
            if (trustInfo.stakerAddresses[i] == trustInfo.staker) {
                stakerExist = true;
                break;
            }
        }

        if (!borrowerExist) {
            members[trustInfo.staker].creditLine.borrowerAddresses.push(borrower);
        }

        if (!stakerExist) {
            members[borrower].creditLine.stakerAddresses.push(trustInfo.staker);
        }

        members[trustInfo.staker].creditLine.borrowers[borrower] = trustAmount;
        members[borrower].creditLine.stakers[trustInfo.staker] = trustAmount;
        emit LogUpdateTrust(trustInfo.staker, borrower, trustAmount);
    }

    /**
     *  @dev Stop vouch for other member.
     *  Only callable by a member when the contract is not paused
     *  Emit {LogCancelVouch} event
     *  @param staker Staker address
     *  @param borrower borrower address
     */
    function cancelVouch(address staker, address borrower) external override onlyMember(msg.sender) whenNotPaused {
        if (msg.sender != staker && msg.sender != borrower) revert AuthFailed();
        if (getLockedStake(staker, borrower) != 0) revert LockedStakeNonZero();
        uint256 stakerCount = members[borrower].creditLine.stakerAddresses.length;
        bool stakerExist = false;
        uint256 stakerIndex = 0;
        for (uint256 i = 0; i < stakerCount; i++) {
            if (members[borrower].creditLine.stakerAddresses[i] == staker) {
                stakerExist = true;
                stakerIndex = i;
                break;
            }
        }

        uint256 borrowerCount = members[staker].creditLine.borrowerAddresses.length;
        bool borrowerExist = false;
        uint256 borrowerIndex = 0;
        for (uint256 i = 0; i < borrowerCount; i++) {
            if (members[staker].creditLine.borrowerAddresses[i] == borrower) {
                borrowerExist = true;
                borrowerIndex = i;
                break;
            }
        }

        //delete address
        if (borrowerExist) {
            members[staker].creditLine.borrowerAddresses[borrowerIndex] = members[staker].creditLine.borrowerAddresses[
                borrowerCount - 1
            ];
            members[staker].creditLine.borrowerAddresses.pop();
        }

        if (stakerExist) {
            members[borrower].creditLine.stakerAddresses[stakerIndex] = members[borrower].creditLine.stakerAddresses[
                stakerCount - 1
            ];
            members[borrower].creditLine.stakerAddresses.pop();
        }

        delete members[staker].creditLine.borrowers[borrower];
        delete members[borrower].creditLine.stakers[staker];

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
    function registerMember(address newMember) public virtual override whenNotPaused {
        if (checkIsMember(newMember)) revert NoExistingMember();

        IUnionToken unionTokenContract = IUnionToken(unionToken);
        uint256 effectiveStakerNumber = 0;
        address stakerAddress;
        uint256 addressesLength = members[newMember].creditLine.stakerAddresses.length;
        for (uint256 i = 0; i < addressesLength; i++) {
            stakerAddress = members[newMember].creditLine.stakerAddresses[i];
            if (checkIsMember(stakerAddress) && getVouchingAmount(stakerAddress, newMember) > 0)
                effectiveStakerNumber += 1;
        }

        if (effectiveStakerNumber < creditLimitModel.effectiveNumber()) revert NotEnoughStakers();

        members[newMember].isMember = true;

        unionTokenContract.burnFrom(msg.sender, newMemberFee);

        emit LogRegisterMember(msg.sender, newMember);
    }

    /**
     *  @dev Updates locked amounts for this borrowers stakers
     *  @param amount Amount being locked
     *  @param isBorrow if this is a borrow or a repayment
     */
    function updateLockedData(
        address borrower,
        uint256 amount,
        bool isBorrow
    ) external override onlyMarketOrAdmin {
        TrustInfo memory trustInfo;
        trustInfo.stakerAddresses = members[borrower].creditLine.stakerAddresses;

        ICreditLimitModel.LockedInfo[] memory lockedInfoList = new ICreditLimitModel.LockedInfo[](
            trustInfo.stakerAddresses.length
        );
        uint256 addressesLength = trustInfo.stakerAddresses.length;
        for (uint256 i = 0; i < addressesLength; i++) {
            ICreditLimitModel.LockedInfo memory lockedInfo;

            trustInfo.staker = trustInfo.stakerAddresses[i];
            trustInfo.stakingAmount = stakers[trustInfo.staker];
            trustInfo.vouchingAmount = getVouchingAmount(trustInfo.staker, borrower);

            trustInfo.totalLockedStake = getTotalLockedStake(trustInfo.staker);
            if (trustInfo.stakingAmount <= trustInfo.totalLockedStake) {
                trustInfo.availableStakingAmount = 0;
            } else {
                trustInfo.availableStakingAmount = trustInfo.stakingAmount - trustInfo.totalLockedStake;
            }

            lockedInfo.staker = trustInfo.staker;
            lockedInfo.vouchingAmount = trustInfo.vouchingAmount;
            lockedInfo.lockedAmount = getLockedStake(trustInfo.staker, borrower);
            lockedInfo.availableStakingAmount = trustInfo.availableStakingAmount;

            lockedInfoList[i] = lockedInfo;
        }

        uint256 lockedInfoListLength = lockedInfoList.length;
        for (uint256 i = 0; i < lockedInfoListLength; i++) {
            members[lockedInfoList[i].staker].creditLine.lockedAmount[borrower] = creditLimitModel.getLockedAmount(
                lockedInfoList,
                lockedInfoList[i].staker,
                amount,
                isBorrow
            );
        }
    }

    /**
     *  @dev Stake staking token to earn rewards from the comptroller
     *  Emits a {LogStake} event.
     *  @param amount Amount to stake
     */
    function stake(uint256 amount) public override whenNotPaused nonReentrant {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(stakingToken);

        comptroller.withdrawRewards(msg.sender, stakingToken);

        uint256 balance = stakers[msg.sender];

        if (balance + amount > maxStakeAmount) revert StakeLimitReached();

        stakers[msg.sender] = balance + amount;
        totalStaked += amount;

        erc20Token.safeTransferFrom(msg.sender, address(this), amount);
        erc20Token.safeApprove(assetManager, 0);
        erc20Token.safeApprove(assetManager, amount);

        if (!IAssetManager(assetManager).deposit(stakingToken, amount)) revert AssetManagerDepositFailed();
        emit LogStake(msg.sender, amount);
    }

    /**
     *  @dev Stake using DAI permit
     *  @param amount Amount to stake
     *  @param nonce Nonce
     *  @param expiry Timestamp for when the permit expires
     *  @param v secp256k1 signature part
     *  @param r secp256k1 signature part
     *  @param s secp256k1 signature part
     */
    function stakeWithPermit(
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        IDai erc20Token = IDai(stakingToken);
        erc20Token.permit(msg.sender, address(this), nonce, expiry, true, v, r, s);

        stake(amount);
    }

    /**
     *  @dev Stake using ERC20 permit
     *  @param amount Amount
     */
    function stakeWithERC20Permit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        IERC20Permit erc20Token = IERC20Permit(stakingToken);
        erc20Token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        stake(amount);
    }

    /**
     *  @dev Unstake staking token from comptroller
     *  Emits {LogUnstake} event
     *  @param amount Amount to unstake
     */
    function unstake(uint256 amount) external override whenNotPaused nonReentrant {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(stakingToken);
        uint256 stakingAmount = stakers[msg.sender];

        if (stakingAmount - getTotalLockedStake(msg.sender) < amount) revert InsufficientBalance();

        comptroller.withdrawRewards(msg.sender, stakingToken);

        stakers[msg.sender] = stakingAmount - amount;
        totalStaked -= amount;

        if (!IAssetManager(assetManager).withdraw(stakingToken, address(this), amount))
            revert AssetManagerWithdrawFailed();

        erc20Token.safeTransfer(msg.sender, amount);

        emit LogUnstake(msg.sender, amount);
    }

    function withdrawRewards() external whenNotPaused nonReentrant {
        comptroller.withdrawRewards(msg.sender, stakingToken);
    }

    /**
     *  @dev Repay user's loan overdue, called only from the lending market
     *  @param account User address
     *  @param token The asset token repaying to
     *  @param lastRepay Last repay block number
     */
    function repayLoanOverdue(
        address account,
        address token,
        uint256 lastRepay
    ) external override whenNotPaused onlyMarketOrAdmin {
        address[] memory stakerAddresses = getStakerAddresses(account);
        uint256 addressesLength;
        for (uint256 i = 0; i < addressesLength; i++) {
            address staker = stakerAddresses[i];
            (, , uint256 lockedStake) = getStakerAsset(account, staker);

            comptroller.addFrozenCoinAge(staker, token, lockedStake, lastRepay);
        }
    }

    /**
     *  @dev Write off a borrowers debt
     *  Emits {LogDebtWriteOff} event
     *  @param borrower address of borrower
     *  @param amount amount to writeoff
     */
    function debtWriteOff(address borrower, uint256 amount) public {
        if (amount == 0) revert AmountZero();
        if (amount > totalStaked) revert ExceedsTotalStaked();
        if (!uToken.checkIsOverdue(borrower)) revert NotOverdue();

        uint256 lockedAmount = getLockedStake(msg.sender, borrower);
        if (amount > lockedAmount) revert ExceedsLocked();

        _updateTotalFrozen(borrower, true);
        if (amount > totalFrozen) revert ExceedsTotalFrozen();

        comptroller.withdrawRewards(msg.sender, stakingToken);

        //The borrower is still overdue, do not call comptroller.addFrozenCoinAge

        stakers[msg.sender] -= amount;
        totalStaked -= amount;
        totalFrozen -= amount;
        if (memberFrozen[borrower] >= amount) {
            memberFrozen[borrower] -= amount;
        } else {
            memberFrozen[borrower] = 0;
        }
        members[msg.sender].creditLine.lockedAmount[borrower] = lockedAmount - amount;
        uint256 trustAmount = members[msg.sender].creditLine.borrowers[borrower];
        uint256 newTrustAmount = trustAmount - amount;
        members[msg.sender].creditLine.borrowers[borrower] = newTrustAmount;
        members[borrower].creditLine.stakers[msg.sender] = newTrustAmount;
        IAssetManager(assetManager).debtWriteOff(stakingToken, amount);
        uToken.debtWriteOff(borrower, amount);
        emit LogDebtWriteOff(msg.sender, borrower, amount);
    }

    /**
     *  @dev Update total frozen
     *  @param account borrower address
     *  @param isOverdue account is overdue
     */
    function updateTotalFrozen(address account, bool isOverdue) external override onlyMarketOrAdmin whenNotPaused {
        if (totalStaked < totalFrozen) revert ErrorTotalStake();
        uint256 effectiveTotalStaked = totalStaked - totalFrozen;
        comptroller.updateTotalStaked(stakingToken, effectiveTotalStaked);
        _updateTotalFrozen(account, isOverdue);
    }

    /**
     *  @dev Batch update total Frozen
     *  @param accounts array of accounts to update frozen for
     *  @param isOverdues array of bools to determine if the account is overdue
     */
    function batchUpdateTotalFrozen(address[] calldata accounts, bool[] calldata isOverdues)
        external
        override
        onlyMarketOrAdmin
        whenNotPaused
    {
        if (accounts.length != isOverdues.length) revert LengthNotMatch();
        if (totalStaked < totalFrozen) revert ErrorTotalStake();
        uint256 effectiveTotalStaked = totalStaked - totalFrozen;
        comptroller.updateTotalStaked(stakingToken, effectiveTotalStaked);
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) _updateTotalFrozen(accounts[i], isOverdues[i]);
        }
    }

    function _updateTotalFrozen(address account, bool isOverdue) private {
        if (isOverdue) {
            //isOverdue = true, user overdue needs to increase totalFrozen

            //The sum of the locked amount of all stakers on this borrower, which is the frozen amount that needs to be updated
            uint256 amount;
            for (uint256 i = 0; i < members[account].creditLine.stakerAddresses.length; i++) {
                address staker = members[account].creditLine.stakerAddresses[i];
                uint256 lockedStake = getLockedStake(staker, account);
                amount += lockedStake;
            }

            if (memberFrozen[account] == 0) {
                //I haven’t updated the frozen amount about this borrower before, just increase the amount directly
                totalFrozen += amount;
            } else {
                //I have updated the frozen amount of this borrower before. After increasing the amount, subtract the previously increased value to avoid repeated additions.
                totalFrozen = totalFrozen + amount - memberFrozen[account];
            }
            //Record the increased value of this borrower this time
            memberFrozen[account] = amount;
        } else {
            //isOverdue = false, the user loan needs to reduce the number of frozen last time to return to normal
            if (totalFrozen > memberFrozen[account]) {
                //Minus the frozen amount added last time
                totalFrozen -= memberFrozen[account];
            } else {
                totalFrozen = 0;
            }
            memberFrozen[account] = 0;
        }
    }

    /**
     * @dev get frozen coin age
     * @param staker address of the staker
     * @param pastBlocks past blocks
     */
    function getFrozenCoinAge(address staker, uint256 pastBlocks) public view override returns (uint256) {
        uint256 totalFrozenCoinAge = 0;

        address[] memory borrowerAddresses = getBorrowerAddresses(staker);
        uint256 addressLength = borrowerAddresses.length;
        for (uint256 i = 0; i < addressLength; i++) {
            address borrower = borrowerAddresses[i];
            uint256 blocks = block.number - uToken.getLastRepay(borrower);
            if (uToken.checkIsOverdue(borrower)) {
                (, , uint256 lockedStake) = getStakerAsset(borrower, staker);

                if (pastBlocks >= blocks) {
                    totalFrozenCoinAge = totalFrozenCoinAge + (lockedStake * blocks);
                } else {
                    totalFrozenCoinAge = totalFrozenCoinAge + (lockedStake * pastBlocks);
                }
            }
        }

        return totalFrozenCoinAge;
    }

    /**
     *  @dev Max number of vouches for a member can get, for ddos protection
     */
    function _maxTrust() internal pure virtual returns (uint256) {
        return 25;
    }
}
