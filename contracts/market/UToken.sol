//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {ScaledDecimalBase} from "../ScaledDecimalBase.sol";
import {Controller} from "../Controller.sol";
import {IUserManager} from "../interfaces/IUserManager.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {IUToken} from "../interfaces/IUToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
}

/**
 *  @title UToken Contract
 *  @dev Union accountBorrows can borrow and repay thru this component.
 */
contract UToken is IUToken, Controller, ERC20PermitUpgradeable, ReentrancyGuardUpgradeable, ScaledDecimalBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUpgradeable for uint256;

    /* -------------------------------------------------------------------
      Types 
    ------------------------------------------------------------------- */

    struct BorrowSnapshot {
        uint256 principal;
        uint256 interest;
        uint256 interestIndex;
        uint256 lastRepay; //Calculate if it is overdue
    }

    struct InitParams {
        string name;
        string symbol;
        address underlying;
        uint256 initialExchangeRateMantissa;
        uint256 reserveFactorMantissa;
        uint256 originationFee;
        uint256 originationFeeMax;
        uint256 debtCeiling;
        uint256 maxBorrow;
        uint256 minBorrow;
        uint256 overdueTime;
        address admin;
        uint256 mintFeeRate;
    }

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev Wad do you want
     */
    uint256 public constant WAD = 1e18;

    /**
     *  @dev Minimum mint amount
     */
    uint256 public minMintAmount;

    /**
     * @dev Maximum borrow rate that can ever be applied (.005% / 12 second)
     */
    uint256 internal constant BORROW_RATE_MAX_MANTISSA = 4_166_666_666_667; // 0.005e16 / 12

    /**
     *  @dev Maximum fraction of interest that can be set aside for reserves
     */
    uint256 internal constant RESERVE_FACTORY_MAX_MANTISSA = 1e18;

    /**
     *  @dev Initial exchange rate used when minting the first UTokens (used when totalSupply = 0)
     */
    uint256 public initialExchangeRateMantissa;

    /**
     *  @dev Fraction of interest currently set aside for reserves
     */
    uint256 public reserveFactorMantissa;

    /**
     *  @dev Block timestamp that interest was last accrued at
     */
    uint256 public accrualTimestamp;

    /**
     *  @dev Accumulator of the total earned interest rate since the opening of the market
     */
    uint256 public borrowIndex;

    /**
     *  @dev Total amount of outstanding borrows of the underlying in this market
     */
    uint256 private _totalBorrows;

    /**
     *  @dev Total amount of reserves of the underlying held in this market
     */
    uint256 private _totalReserves;

    /**
     *  @dev Calculates the exchange rate from the underlying to the uToken
     */
    uint256 private _totalRedeemable;

    /**
     *  @dev overdue duration, in seconds
     */
    uint256 public override overdueTime;

    /**
     *  @dev fee paid at loan origin
     */
    uint256 public originationFee;

    /**
     * @dev The max allowed value for originationFee
     */
    uint256 public originationFeeMax;

    /**
     *  @dev The debt limit for the whole system
     */
    uint256 private _debtCeiling;

    /**
     *  @dev Max amount that can be borrowed by a single member
     */
    uint256 private _maxBorrow;

    /**
     *  @dev Min amount that can be borrowed by a single member
     */
    uint256 private _minBorrow;

    /**
     *  @dev Asset manager contract address
     */
    address public assetManager;

    /**
     *  @dev User manager contract address
     */
    address public userManager;

    /**
     * @dev Address of underlying token
     */
    address public underlying;

    uint8 public underlyingDecimal;

    /**
     * @dev Interest rate model used for calculating interest rate
     */
    IInterestRateModel public interestRateModel;

    /**
     * @notice Mapping of account addresses to outstanding borrow balances
     */
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /**
     *  @dev fee charged on minting UToken to prevent frontrun attack on repayments
     */
    uint256 public mintFeeRate;

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error AccrueInterestFailed();
    error AccrueBlockParity();
    error AmountExceedGlobalMax();
    error AmountExceedMaxBorrow();
    error AmountLessMinBorrow();
    error AmountError();
    error AmountZero();
    error BorrowRateExceedLimit();
    error WithdrawFailed();
    error CallerNotMember();
    error CallerNotUserManager();
    error InitExchangeRateNotZero();
    error InsufficientFundsLeft();
    error MemberIsOverdue();
    error ReserveFactoryExceedLimit();
    error DepositToAssetManagerFailed();
    error OriginationFeeExceedLimit();
    error MintFeeError();

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Change of the interest rate model
     *  @param oldInterestRateModel Old interest rate model address
     *  @param newInterestRateModel New interest rate model address
     */
    event LogNewMarketInterestRateModel(address oldInterestRateModel, address newInterestRateModel);

    /**
     *  @dev Mint uToken by depositing token
     *  @param minter address of minter
     *  @param underlyingAmount amount of underlying token
     *  @param uTokenAmount amount of uToken
     */
    event LogMint(address minter, uint256 underlyingAmount, uint256 uTokenAmount);

    /**
     *  @dev Redeem token for uToken
     */
    event LogRedeem(address redeemer, uint256 amountIn, uint256 amountOut, uint256 uTokenAmount, uint256 redeemAmount);

    /**
     *  @dev Token added to the reserves
     *  @param reserver address of sender that added to reservers
     *  @param actualAddAmount amount of tokens added
     *  @param totalReservesNew new total reserve amount
     */
    event LogReservesAdded(address reserver, uint256 actualAddAmount, uint256 totalReservesNew);

    /**
     *  @dev Token removed from the reserves
     *  @param receiver receiver address of tokens
     *  @param reduceAmount amount of tokens to withdraw
     *  @param totalReservesNew new total reserves amount
     */
    event LogReservesReduced(address receiver, uint256 reduceAmount, uint256 totalReservesNew);

    /**
     *  @dev Event borrow
     *  @param account Member address
     *  @param amount Borrow amount
     *  @param fee Origination fee
     */
    event LogBorrow(address indexed account, address indexed to, uint256 amount, uint256 fee);

    /**
     *  @dev Event repay
     *  @param account Member address
     *  @param amount Repay amount
     */
    event LogRepay(address indexed payer, address indexed account, uint256 amount);

    /**
     *  @dev Event minter fee rate change
     *  @param oldRate Old rate
     *  @param newRate New rate
     */
    event LogMintFeeRateChanged(uint256 oldRate, uint256 newRate);

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    /**
     *  @dev modifier limit member
     */
    modifier onlyMember(address account) {
        if (!IUserManager(userManager).checkIsMember(account)) revert CallerNotMember();
        _;
    }

    modifier onlyUserManager() {
        if (msg.sender != userManager) revert CallerNotUserManager();
        _;
    }

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __UToken_init(InitParams memory params) public initializer {
        if (params.initialExchangeRateMantissa == 0) revert InitExchangeRateNotZero();
        if (params.reserveFactorMantissa > RESERVE_FACTORY_MAX_MANTISSA) revert ReserveFactoryExceedLimit();
        Controller.__Controller_init(params.admin);
        ERC20Upgradeable.__ERC20_init(params.name, params.symbol);
        ERC20PermitUpgradeable.__ERC20Permit_init(params.name);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        underlying = params.underlying;
        underlyingDecimal = IERC20(params.underlying).decimals();
        minMintAmount = 10 ** underlyingDecimal;
        originationFee = params.originationFee;
        originationFeeMax = params.originationFeeMax;
        _debtCeiling = decimalScaling(params.debtCeiling, underlyingDecimal);
        _maxBorrow = decimalScaling(params.maxBorrow, underlyingDecimal);
        _minBorrow = decimalScaling(params.minBorrow, underlyingDecimal);
        overdueTime = params.overdueTime;
        initialExchangeRateMantissa = params.initialExchangeRateMantissa;
        reserveFactorMantissa = params.reserveFactorMantissa;
        mintFeeRate = params.mintFeeRate;
        accrualTimestamp = getTimestamp();
        borrowIndex = WAD;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    /**
     *  @dev set Asset Manager contract address
     *  Accept claims only from the admin
     */
    function setAssetManager(address assetManager_) external onlyAdmin {
        assetManager = assetManager_;
    }

    /**
     *  @dev set User Manager contract address
     *  Accept claims only from the admin
     */
    function setUserManager(address userManager_) external onlyAdmin {
        userManager = userManager_;
    }

    /**
     *  @dev Change loan origination fee value
     *  Accept claims only from the admin
     *  @param originationFee_ Fees deducted for each loan transaction
     */
    function setOriginationFee(uint256 originationFee_) external override onlyAdmin {
        if (originationFee_ > originationFeeMax) revert OriginationFeeExceedLimit();
        originationFee = originationFee_;
    }

    /**
     *  @dev Update the market debt ceiling to a fixed amount, for example, 1 billion DAI etc.
     *  Accept claims only from the admin
     *  @param debtCeiling_ The debt limit for the whole system
     */
    function setDebtCeiling(uint256 debtCeiling_) external override onlyAdmin {
        uint256 actualDebtCeiling = decimalScaling(debtCeiling_, underlyingDecimal);
        _debtCeiling = actualDebtCeiling;
    }

    /**
     *  @dev Update the minimum loan size
     *  Accept claims only from the admin
     *  @param minBorrow_ Minimum loan amount per user
     */
    function setMinBorrow(uint256 minBorrow_) external override onlyAdmin {
        uint256 actualMinBorrow = decimalScaling(minBorrow_, underlyingDecimal);
        _minBorrow = actualMinBorrow;
    }

    /**
     *  @dev Update the max loan size
     *  Accept claims only from the admin
     *  @param maxBorrow_ Max loan amount per user
     */
    function setMaxBorrow(uint256 maxBorrow_) external override onlyAdmin {
        uint256 actualMaxBorrow = decimalScaling(maxBorrow_, underlyingDecimal);
        _maxBorrow = actualMaxBorrow;
    }

    /**
     *  @dev Change loan overdue duration, in seconds
     *  Accept claims only from the admin
     *  @param overdueTime_ Maximum late repayment time. The number of arrivals is a default
     */
    function setOverdueTime(uint256 overdueTime_) external override onlyAdmin {
        overdueTime = overdueTime_;
    }

    /**
     *  @dev Change to a different interest rate model
     *  Accept claims only from the admin
     *  @param newInterestRateModel_ New interest rate model address
     */
    function setInterestRateModel(address newInterestRateModel_) external override onlyAdmin {
        address oldInterestRateModel = address(interestRateModel);
        address newInterestRateModel = newInterestRateModel_;
        interestRateModel = IInterestRateModel(newInterestRateModel);
        emit LogNewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel);
    }

    /**
     *  @dev set reserve factor mantissa
     *  Accept claims only from the admin
     */
    function setReserveFactor(uint256 reserveFactorMantissa_) external override onlyAdmin {
        if (reserveFactorMantissa_ > RESERVE_FACTORY_MAX_MANTISSA) revert ReserveFactoryExceedLimit();
        reserveFactorMantissa = reserveFactorMantissa_;
    }

    /**
     *  @dev Change minter fee rate
     *  Only admin can call this function
     *  @param newRate New minter fee rate
     */
    function setMintFeeRate(uint256 newRate) external override onlyAdmin {
        if (newRate > 1e17) revert MintFeeError();
        uint256 oldRate = mintFeeRate;
        mintFeeRate = newRate;

        emit LogMintFeeRateChanged(oldRate, newRate);
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */
    function debtCeiling() public view returns (uint256) {
        return decimalReducing(_debtCeiling, underlyingDecimal);
    }

    function maxBorrow() public view returns (uint256) {
        return decimalReducing(_maxBorrow, underlyingDecimal);
    }

    function minBorrow() public view returns (uint256) {
        return decimalReducing(_minBorrow, underlyingDecimal);
    }

    function totalBorrows() public view returns (uint256) {
        return decimalReducing(_totalBorrows, underlyingDecimal);
    }

    function totalReserves() public view returns (uint256) {
        return decimalReducing(_totalReserves, underlyingDecimal);
    }

    function totalRedeemable() public view returns (uint256) {
        return decimalReducing(_totalRedeemable, underlyingDecimal);
    }

    /**
     *  @dev Returns the remaining amount that can be borrowed from the market.
     *  @return Remaining total amount
     */
    function getRemainingDebtCeiling() public view override returns (uint256) {
        return decimalReducing(_debtCeiling >= _totalBorrows ? _debtCeiling - _totalBorrows : 0, underlyingDecimal);
    }

    /**
     *  @dev Get the last repay time
     *  @param account Member address
     *  @return lastRepay
     */
    function getLastRepay(address account) public view override returns (uint256) {
        return accountBorrows[account].lastRepay;
    }

    /**
     *  @dev Check if the member's loan is overdue
     *  @param account Member address
     *  @return isOverdue
     */
    function checkIsOverdue(address account) public view override returns (bool isOverdue) {
        if (_getBorrowed(account) != 0) {
            uint256 lastRepay = getLastRepay(account);
            uint256 diff = getTimestamp() - lastRepay;
            isOverdue = overdueTime < diff;
        }
    }

    /**
     *  @dev Get the origination fee
     *  @param amount Amount to be calculated
     *  @return Handling fee
     */
    function calculatingFee(uint256 amount) public view override returns (uint256) {
        return (originationFee * amount) / WAD;
    }

    /**
     *  @dev Get the borrowed principle
     *  @param account Member address
     *  @return borrowed
     */
    function getBorrowed(address account) public view override returns (uint256) {
        return decimalReducing(_getBorrowed(account), underlyingDecimal);
    }

    function _getBorrowed(address account) private view returns (uint256) {
        return accountBorrows[account].principal;
    }

    /**
     *  @dev Get a member's current owed balance, including the principle and interest but without updating the user's states.
     *  @param account Member address
     *  @return Borrowed amount
     */
    function borrowBalanceView(address account) public view override returns (uint256) {
        return getBorrowed(account) + calculatingInterest(account);
    }

    function _borrowBalanceView(address account) public view returns (uint256) {
        return _getBorrowed(account) + _calculatingInterest(account);
    }

    /**
     *  @dev Get a member's total owed, including the principle and the interest calculated based on the interest index.
     *  @param account Member address
     *  @return Borrowed amount
     */
    function borrowBalanceStoredInternal(address account) internal view returns (uint256) {
        BorrowSnapshot memory loan = accountBorrows[account];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (loan.principal == 0) {
            return 0;
        }

        uint256 principalTimesIndex = (loan.principal + loan.interest) * borrowIndex;
        return principalTimesIndex / loan.interestIndex;
    }

    /**
     *  @dev Get the borrowing interest rate per second
     *  @return Borrow rate
     */
    function borrowRatePerSecond() public view override returns (uint256) {
        uint256 borrowRateMantissa = interestRateModel.getBorrowRate();
        if (borrowRateMantissa > BORROW_RATE_MAX_MANTISSA) revert BorrowRateExceedLimit();

        return borrowRateMantissa;
    }

    /**
     * @notice Returns the current per-second supply interest rate for this UToken
     * @return The supply interest rate per second, scaled by 1e18
     */
    function supplyRatePerSecond() external view override returns (uint256) {
        return interestRateModel.getSupplyRate(reserveFactorMantissa);
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the UToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function _exchangeRateStored() private view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        return totalSupply_ == 0 ? initialExchangeRateMantissa : (_totalRedeemable * WAD) / totalSupply_;
    }

    function exchangeRateStored() public view returns (uint256) {
        return decimalReducing(_exchangeRateStored(), underlyingDecimal);
    }

    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() public nonReentrant returns (uint256) {
        if (!accrueInterest()) revert AccrueInterestFailed();
        return _exchangeRateStored();
    }

    /**
     *  @dev Calculating member's borrowed interest
     *  @param account Member address
     *  @return Interest amount
     */
    function calculatingInterest(address account) public view override returns (uint256) {
        return decimalReducing(_calculatingInterest(account), underlyingDecimal);
    }

    function _calculatingInterest(address account) private view returns (uint256) {
        BorrowSnapshot memory loan = accountBorrows[account];

        if (loan.principal == 0) {
            return 0;
        }

        uint256 borrowRate = borrowRatePerSecond();
        uint256 currentTimestamp = getTimestamp();
        uint256 timeDelta = currentTimestamp - accrualTimestamp;
        uint256 simpleInterestFactor = borrowRate * timeDelta;
        uint256 borrowIndexNew = (simpleInterestFactor * borrowIndex) / WAD + borrowIndex;

        uint256 principalTimesIndex = (loan.principal + loan.interest) * borrowIndexNew;
        uint256 balance = principalTimesIndex / loan.interestIndex;

        return balance - _getBorrowed(account);
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external view override returns (uint256) {
        return decimalReducing((_exchangeRateStored() * balanceOf(owner)) / WAD, underlyingDecimal);
    }

    /* -------------------------------------------------------------------
       Borrowing/Repay Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Borrowing from the market
     *  Accept claims only from the member
     *  Borrow amount must in the range of creditLimit, _minBorrow, _maxBorrow, _debtCeiling and not overdue
     *  @param amount Borrow amount
     */
    function borrow(address to, uint256 amount) external override onlyMember(msg.sender) whenNotPaused nonReentrant {
        IAssetManager assetManagerContract = IAssetManager(assetManager);
        uint256 actualAmount = decimalScaling(amount, underlyingDecimal);
        if (actualAmount < _minBorrow) revert AmountLessMinBorrow();

        // Calculate the origination fee
        uint256 fee = calculatingFee(actualAmount);

        if (_borrowBalanceView(msg.sender) + actualAmount + fee > _maxBorrow) revert AmountExceedMaxBorrow();
        if (checkIsOverdue(msg.sender)) revert MemberIsOverdue();
        if (amount > assetManagerContract.getLoanableAmount(underlying)) revert InsufficientFundsLeft();
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 borrowedAmount = borrowBalanceStoredInternal(msg.sender);

        // Initialize the last repayment date to the current block timestamp
        if (getLastRepay(msg.sender) == 0) {
            accountBorrows[msg.sender].lastRepay = getTimestamp();
        }

        // Withdraw the borrowed amount of tokens from the assetManager and send them to the borrower
        uint256 remaining = assetManagerContract.withdraw(underlying, to, amount);
        if (remaining > amount) revert WithdrawFailed();
        actualAmount -= decimalScaling(remaining, underlyingDecimal);

        fee = calculatingFee(actualAmount);
        uint256 accountBorrowsNew = borrowedAmount + actualAmount + fee;
        uint256 totalBorrowsNew = _totalBorrows + actualAmount + fee;
        if (totalBorrowsNew > _debtCeiling) revert AmountExceedGlobalMax();

        // Update internal balances
        accountBorrows[msg.sender].principal += actualAmount + fee;
        uint256 newPrincipal = _getBorrowed(msg.sender);
        accountBorrows[msg.sender].interest = accountBorrowsNew - newPrincipal;
        accountBorrows[msg.sender].interestIndex = borrowIndex;
        _totalBorrows = totalBorrowsNew;

        // The origination fees contribute to the reserve and not to the
        // uDAI minters redeemable amount.
        _totalReserves += fee;

        // Call update locked on the userManager to lock this borrowers stakers. This function
        // will revert if the account does not have enough vouchers to cover the borrow amount. ie
        // the borrower is trying to borrow more than is able to be underwritten

        IUserManager(userManager).updateLocked(
            msg.sender,
            decimalReducing(actualAmount + fee, underlyingDecimal),
            true
        );

        emit LogBorrow(msg.sender, to, actualAmount, fee);
    }

    /**
     * @dev Helper function to repay interest amount
     * @param borrower Borrower address
     */
    function repayInterest(address borrower) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 interest = _calculatingInterest(borrower);
        _repayBorrowFresh(msg.sender, borrower, interest, interest);
    }

    /**
     * @notice Repay outstanding borrow
     * @dev Repay borrow see _repayBorrowFresh
     */
    function repayBorrow(address borrower, uint256 amount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 actualAmount = decimalScaling(amount, underlyingDecimal);
        uint256 interest = _calculatingInterest(borrower);
        _repayBorrowFresh(msg.sender, borrower, actualAmount, interest);
    }

    /**
     *  @dev Repay the loan
     *  Updated member lastPaymentEpoch only when the repayment amount is greater than interest
     *  @param payer Payer address
     *  @param borrower Borrower address
     *  @param amount Repay amount
     *  @param interest Interest amount
     */
    function _repayBorrowFresh(address payer, address borrower, uint256 amount, uint256 interest) internal {
        uint256 currTime = getTimestamp();
        if (currTime != accrualTimestamp) revert AccrueBlockParity();
        uint256 borrowedAmount = borrowBalanceStoredInternal(borrower);
        uint256 repayAmount = amount > borrowedAmount ? borrowedAmount : amount;
        if (repayAmount == 0) revert AmountZero();

        uint256 toReserveAmount;
        uint256 toRedeemableAmount;

        if (repayAmount >= interest) {
            // Interest is split between the reserves and the uToken minters based on
            // the reserveFactorMantissa When set to WAD all the interest is paid to teh reserves.
            // any interest that isn't sent to the reserves is added to the redeemable amount
            // and can be redeemed by uToken minters.
            toReserveAmount = (interest * reserveFactorMantissa) / WAD;
            toRedeemableAmount = interest - toReserveAmount;

            // Update the total borrows to reduce by the amount of principal that has
            // been paid off
            _totalBorrows -= (repayAmount - interest);

            // Update the account borrows to reflect the repayment
            accountBorrows[borrower].principal = borrowedAmount - repayAmount;
            accountBorrows[borrower].interest = 0;

            uint256 pastTime = currTime - getLastRepay(borrower);
            if (pastTime > overdueTime) {
                // For borrowers that are paying back overdue balances we need to update their
                // frozen balance and the global total frozen balance on the UserManager
                IUserManager(userManager).onRepayBorrow(borrower, getLastRepay(borrower) + overdueTime);
            }

            // Call update locked on the userManager to lock this borrowers stakers. This function
            // will revert if the account does not have enough vouchers to cover the repay amount. ie
            // the borrower is trying to repay more than is locked (owed)
            IUserManager(userManager).updateLocked(
                borrower,
                decimalReducing(repayAmount - interest, underlyingDecimal),
                false
            );

            if (_getBorrowed(borrower) == 0) {
                // If the principal is now 0 we can reset the last repaid time to 0.
                // which indicates that the borrower has no outstanding loans.
                accountBorrows[borrower].lastRepay = 0;
            } else {
                // Save the current block timestamp as last repaid
                accountBorrows[borrower].lastRepay = currTime;
            }
        } else {
            // For repayments that don't pay off the minimum we just need to adjust the
            // global balances and reduce the amount of interest accrued for the borrower
            toReserveAmount = (repayAmount * reserveFactorMantissa) / WAD;
            toRedeemableAmount = repayAmount - toReserveAmount;
            accountBorrows[borrower].interest = interest - repayAmount;
        }

        _totalReserves += toReserveAmount;
        _totalRedeemable += toRedeemableAmount;

        accountBorrows[borrower].interestIndex = borrowIndex;

        // Transfer underlying token that have been repaid and then deposit
        // then in the asset manager so they can be distributed between the
        // underlying money markets
        uint256 sendAmount = decimalReducing(repayAmount, underlyingDecimal);
        IERC20Upgradeable(underlying).safeTransferFrom(payer, address(this), sendAmount);
        _depositToAssetManager(sendAmount);

        emit LogRepay(payer, borrower, sendAmount);
    }

    /**
     *  @dev Accrue interest
     *  @return Accrue interest finished
     */
    function accrueInterest() public override returns (bool) {
        uint256 borrowRate = borrowRatePerSecond();
        uint256 currentTimestamp = getTimestamp();
        uint256 timeDelta = currentTimestamp - accrualTimestamp;

        uint256 simpleInterestFactor = borrowRate * timeDelta;
        uint256 borrowIndexNew = (simpleInterestFactor * borrowIndex) / WAD + borrowIndex;

        accrualTimestamp = currentTimestamp;
        borrowIndex = borrowIndexNew;

        return true;
    }

    function debtWriteOff(address borrower, uint256 amount) external override whenNotPaused onlyUserManager {
        if (amount == 0) revert AmountZero();
        uint256 actualAmount = decimalScaling(amount, underlyingDecimal);

        uint256 oldPrincipal = _getBorrowed(borrower);
        uint256 repayAmount = actualAmount > oldPrincipal ? oldPrincipal : actualAmount;

        accountBorrows[borrower].principal = oldPrincipal - repayAmount;
        _totalBorrows -= repayAmount;

        if (repayAmount == oldPrincipal) {
            // If all principal is written off, we can reset the last repaid time to 0.
            // which indicates that the borrower has no outstanding loans.
            accountBorrows[borrower].lastRepay = 0;
        }
    }

    /* -------------------------------------------------------------------
       mint and redeem uToken Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Mint uTokens by depositing tokens
     * @param amountIn The amount of the underlying asset to supply
     */
    function mint(uint256 amountIn) external override whenNotPaused nonReentrant {
        if (amountIn < minMintAmount) revert AmountError();
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 exchangeRate = _exchangeRateStored();
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        assetToken.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 actualObtained = balanceAfter - balanceBefore;
        uint256 mintTokens = 0;
        uint256 totalAmount = decimalScaling(actualObtained, underlyingDecimal);
        uint256 mintFee = decimalScaling((actualObtained * mintFeeRate) / WAD, underlyingDecimal);
        if (mintFee > 0) {
            // Minter fee goes to the reserve
            _totalReserves += mintFee;
        }
        // Rest goes to minting UToken
        uint256 mintAmount = totalAmount - mintFee;
        _totalRedeemable += mintAmount;
        mintTokens = (mintAmount * WAD) / exchangeRate;
        _mint(msg.sender, mintTokens);
        // send all to asset manager
        _depositToAssetManager(balanceAfter - balanceBefore);

        emit LogMint(msg.sender, mintAmount, mintTokens);
    }

    /**
     * @notice User redeems uTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param amountIn The number of uTokens to redeem into underlying
     *        (only one of amountIn or amountOut may be non-zero)
     * @param amountOut The number of underlying tokens to receive from
     *        (only one of amountIn or amountOut may be non-zero)
     */
    function redeem(uint256 amountIn, uint256 amountOut) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        if (amountIn != 0 && amountOut != 0) revert AmountError();
        if (amountIn == 0 && amountOut == 0) revert AmountZero();

        uint256 exchangeRate = _exchangeRateStored();

        // Amount of the underlying token to redeem
        uint256 underlyingAmount = amountOut;

        if (amountIn > 0) {
            // We calculate the exchange rate and the amount of underlying to be redeemed:
            // underlyingAmount = amountIn x _exchangeRateStored
            underlyingAmount = decimalReducing((amountIn * exchangeRate) / WAD, underlyingDecimal);
        }

        uint256 remaining = IAssetManager(assetManager).withdraw(underlying, msg.sender, underlyingAmount);
        // If the remaining amount is greater than or equal to the
        // underlyingAmount then we weren't able to withdraw enough
        // to cover this redemption
        if (remaining >= underlyingAmount) revert WithdrawFailed();

        uint256 actualAmount = decimalScaling(underlyingAmount - remaining, underlyingDecimal);
        uint256 realUtokenAmount = (actualAmount * WAD) / exchangeRate;
        if (realUtokenAmount == 0) revert AmountZero();
        _burn(msg.sender, realUtokenAmount);

        _totalRedeemable -= actualAmount;
        emit LogRedeem(msg.sender, amountIn, amountOut, realUtokenAmount, actualAmount);
    }

    /* -------------------------------------------------------------------
       Reserve Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Add tokens to the reserve
     * @param addAmount amount of tokens to add
     */
    function addReserves(uint256 addAmount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        assetToken.safeTransferFrom(msg.sender, address(this), addAmount);
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 actualAddAmount = decimalScaling(balanceAfter - balanceBefore, underlyingDecimal);

        _totalReserves += actualAddAmount;

        _depositToAssetManager(balanceAfter);

        emit LogReservesAdded(msg.sender, balanceAfter - balanceBefore, _totalReserves);
    }

    /**
     * @dev Remove tokens to the reserve
     * @param receiver address to receive tokens
     * @param reduceAmount amount of tokens to remove
     */
    function removeReserves(
        address receiver,
        uint256 reduceAmount
    ) external override whenNotPaused nonReentrant onlyAdmin {
        uint256 actualReduceAmount = decimalScaling(reduceAmount, underlyingDecimal);
        if (actualReduceAmount > _totalReserves) revert AmountError();
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 remaining = IAssetManager(assetManager).withdraw(underlying, receiver, reduceAmount);
        if (remaining > reduceAmount) revert WithdrawFailed();
        uint256 actualAmount = decimalScaling(reduceAmount - remaining, underlyingDecimal);
        _totalReserves -= actualAmount;

        emit LogReservesReduced(receiver, actualAmount, _totalReserves);
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Function to simply retrieve block timestamp
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    /**
     *  @dev Deposit tokens to the asset manager
     */
    function _depositToAssetManager(uint256 amount) internal {
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);

        uint256 currentAllowance = assetToken.allowance(address(this), assetManager);
        if (currentAllowance < amount) {
            assetToken.safeIncreaseAllowance(assetManager, amount - currentAllowance);
        }

        if (!IAssetManager(assetManager).deposit(underlying, amount)) revert DepositToAssetManagerFailed();
    }
}
