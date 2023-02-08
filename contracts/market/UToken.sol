//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {Controller} from "../Controller.sol";
import {IUserManager} from "../interfaces/IUserManager.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {IUToken} from "../interfaces/IUToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

/**
 *  @title UToken Contract
 *  @dev Union accountBorrows can borrow and repay thru this component.
 */
contract UToken is IUToken, Controller, ERC20PermitUpgradeable, ReentrancyGuardUpgradeable {
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

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev Wad do you want
     */
    uint256 public constant WAD = 1e18;

    /**
     * @dev Maximum borrow rate that can ever be applied (.005% / block)
     */
    uint256 internal constant BORROW_RATE_MAX_MANTISSA = 0.005e16;

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
     *  @dev Block number that interest was last accrued at
     */
    uint256 public accrualBlockNumber;

    /**
     *  @dev Accumulator of the total earned interest rate since the opening of the market
     */
    uint256 public borrowIndex;

    /**
     *  @dev Total amount of outstanding borrows of the underlying in this market
     */
    uint256 public totalBorrows;

    /**
     *  @dev Total amount of reserves of the underlying held in this market
     */
    uint256 public totalReserves;

    /**
     *  @dev Calculates the exchange rate from the underlying to the uToken
     */
    uint256 public totalRedeemable;

    /**
     *  @dev overdue duration, based on the number of blocks
     */
    uint256 public override overdueBlocks;

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
    uint256 public debtCeiling;

    /**
     *  @dev Max amount that can be borrowed by a single member
     */
    uint256 public maxBorrow;

    /**
     *  @dev Min amount that can be borrowed by a single member
     */
    uint256 public minBorrow;

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

    /**
     * @dev Interest rate model used for calculating interest rate
     */
    IInterestRateModel public interestRateModel;

    /**
     * @notice Mapping of account addresses to outstanding borrow balances
     */
    mapping(address => BorrowSnapshot) internal accountBorrows;

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
    event LogRedeem(address redeemer, uint256 amountIn, uint256 amountOut, uint256 redeemAmount);

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

    function __UToken_init(
        string memory name_,
        string memory symbol_,
        address underlying_,
        uint256 initialExchangeRateMantissa_,
        uint256 reserveFactorMantissa_,
        uint256 originationFee_,
        uint256 originationFeeMax_,
        uint256 debtCeiling_,
        uint256 maxBorrow_,
        uint256 minBorrow_,
        uint256 overdueBlocks_,
        address admin_
    ) public initializer {
        if (initialExchangeRateMantissa_ == 0) revert InitExchangeRateNotZero();
        if (reserveFactorMantissa_ > RESERVE_FACTORY_MAX_MANTISSA) revert ReserveFactoryExceedLimit();
        Controller.__Controller_init(admin_);
        ERC20Upgradeable.__ERC20_init(name_, symbol_);
        ERC20PermitUpgradeable.__ERC20Permit_init(name_);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        underlying = underlying_;
        originationFee = originationFee_;
        originationFeeMax = originationFeeMax_;
        debtCeiling = debtCeiling_;
        maxBorrow = maxBorrow_;
        minBorrow = minBorrow_;
        overdueBlocks = overdueBlocks_;
        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        reserveFactorMantissa = reserveFactorMantissa_;
        accrualBlockNumber = getBlockNumber();
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
        debtCeiling = debtCeiling_;
    }

    /**
     *  @dev Update the minimum loan size
     *  Accept claims only from the admin
     *  @param minBorrow_ Minimum loan amount per user
     */
    function setMinBorrow(uint256 minBorrow_) external override onlyAdmin {
        minBorrow = minBorrow_;
    }

    /**
     *  @dev Update the max loan size
     *  Accept claims only from the admin
     *  @param maxBorrow_ Max loan amount per user
     */
    function setMaxBorrow(uint256 maxBorrow_) external override onlyAdmin {
        maxBorrow = maxBorrow_;
    }

    /**
     *  @dev Change loan overdue duration, based on the number of blocks
     *  Accept claims only from the admin
     *  @param overdueBlocks_ Maximum late repayment block. The number of arrivals is a default
     */
    function setOverdueBlocks(uint256 overdueBlocks_) external override onlyAdmin {
        overdueBlocks = overdueBlocks_;
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

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Returns the remaining amount that can be borrowed from the market.
     *  @return Remaining total amount
     */
    function getRemainingDebtCeiling() public view override returns (uint256) {
        return debtCeiling >= totalBorrows ? debtCeiling - totalBorrows : 0;
    }

    /**
     *  @dev Get the last repay block
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
        if (getBorrowed(account) != 0) {
            uint256 lastRepay = getLastRepay(account);
            uint256 diff = getBlockNumber() - lastRepay;
            isOverdue = overdueBlocks < diff;
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
     *  @dev Get the borrowing interest rate per block
     *  @return Borrow rate
     */
    function borrowRatePerBlock() public view override returns (uint256) {
        uint256 borrowRateMantissa = interestRateModel.getBorrowRate();
        if (borrowRateMantissa > BORROW_RATE_MAX_MANTISSA) revert BorrowRateExceedLimit();

        return borrowRateMantissa;
    }

    /**
     * @notice Returns the current per-block supply interest rate for this UToken
     * @return The supply interest rate per block, scaled by 1e18
     */
    function supplyRatePerBlock() external view override returns (uint256) {
        return interestRateModel.getSupplyRate(reserveFactorMantissa);
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the UToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() public view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        return totalSupply_ == 0 ? initialExchangeRateMantissa : (totalRedeemable * WAD) / totalSupply_;
    }

    /**
     *  @dev Calculating member's borrowed interest
     *  @param account Member address
     *  @return Interest amount
     */
    function calculatingInterest(address account) public view override returns (uint256) {
        BorrowSnapshot memory loan = accountBorrows[account];

        if (loan.principal == 0) {
            return 0;
        }

        uint256 borrowRate = borrowRatePerBlock();
        uint256 currentBlockNumber = getBlockNumber();
        uint256 blockDelta = currentBlockNumber - accrualBlockNumber;
        uint256 simpleInterestFactor = borrowRate * blockDelta;
        uint256 borrowIndexNew = (simpleInterestFactor * borrowIndex) / WAD + borrowIndex;

        uint256 principalTimesIndex = (loan.principal + loan.interest) * borrowIndexNew;
        uint256 balance = principalTimesIndex / loan.interestIndex;

        return balance - getBorrowed(account);
    }

    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() public nonReentrant returns (uint256) {
        if (!accrueInterest()) revert AccrueInterestFailed();
        return exchangeRateStored();
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external view override returns (uint256) {
        return (exchangeRateStored() * balanceOf(owner)) / WAD;
    }

    /* -------------------------------------------------------------------
       Borrowing/Repay Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Borrowing from the market
     *  Accept claims only from the member
     *  Borrow amount must in the range of creditLimit, minBorrow, maxBorrow, debtCeiling and not overdue
     *  @param amount Borrow amount
     */
    function borrow(address to, uint256 amount) external override onlyMember(msg.sender) whenNotPaused nonReentrant {
        IAssetManager assetManagerContract = IAssetManager(assetManager);
        if (amount < minBorrow) revert AmountLessMinBorrow();
        if (amount > getRemainingDebtCeiling()) revert AmountExceedGlobalMax();

        // Calculate the origination fee
        uint256 fee = calculatingFee(amount);

        if (borrowBalanceView(msg.sender) + amount + fee > maxBorrow) revert AmountExceedMaxBorrow();
        if (checkIsOverdue(msg.sender)) revert MemberIsOverdue();
        if (amount > assetManagerContract.getLoanableAmount(underlying)) revert InsufficientFundsLeft();
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 borrowedAmount = borrowBalanceStoredInternal(msg.sender);

        // Initialize the last repayment date to the current block number
        if (getLastRepay(msg.sender) == 0) {
            accountBorrows[msg.sender].lastRepay = getBlockNumber();
        }

        // Withdraw the borrowed amount of tokens from the assetManager and send them to the borrower
        uint256 remaining = assetManagerContract.withdraw(underlying, to, amount);
        if (remaining > amount) revert WithdrawFailed();
        uint256 actualAmount = amount - remaining;

        fee = calculatingFee(actualAmount);
        uint256 accountBorrowsNew = borrowedAmount + actualAmount + fee;
        uint256 totalBorrowsNew = totalBorrows + actualAmount + fee;

        // Update internal balances
        accountBorrows[msg.sender].principal += actualAmount + fee;
        uint256 newPrincipal = getBorrowed(msg.sender);
        accountBorrows[msg.sender].interest = accountBorrowsNew - newPrincipal;
        accountBorrows[msg.sender].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        // The origination fees contribute to the reserve and not to the
        // uDAI minters redeemable amount.
        totalReserves += fee;

        // Call update locked on the userManager to lock this borrowers stakers. This function
        // will revert if the account does not have enough vouchers to cover the borrow amount. ie
        // the borrower is trying to borrow more than is able to be underwritten
        IUserManager(userManager).updateLocked(msg.sender, (actualAmount + fee).toUint96(), true);

        emit LogBorrow(msg.sender, to, actualAmount, fee);
    }

    /**
     * @dev Helper function to repay interest amount
     * @param borrower Borrower address
     */
    function repayInterest(address borrower) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 interest = calculatingInterest(borrower);
        _repayBorrowFresh(msg.sender, borrower, interest, interest);
    }

    /**
     * @notice Repay outstanding borrow
     * @dev Repay borrow see _repayBorrowFresh
     */
    function repayBorrow(address borrower, uint256 amount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 interest = calculatingInterest(borrower);
        _repayBorrowFresh(msg.sender, borrower, amount, interest);
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
        if (getBlockNumber() != accrualBlockNumber) revert AccrueBlockParity();
        uint256 borrowedAmount = borrowBalanceStoredInternal(borrower);
        uint256 repayAmount = amount > borrowedAmount ? borrowedAmount : amount;
        if (repayAmount == 0) revert AmountZero();

        uint256 toReserveAmount;
        uint256 toRedeemableAmount;

        if (repayAmount >= interest) {
            // If the repayment amount is greater than the interest (min payment)
            bool isOverdue = checkIsOverdue(borrower);

            // Interest is split between the reserves and the uToken minters based on
            // the reserveFactorMantissa When set to WAD all the interest is paid to teh reserves.
            // any interest that isn't sent to the reserves is added to the redeemable amount
            // and can be redeemed by uToken minters.
            toReserveAmount = (interest * reserveFactorMantissa) / WAD;
            toRedeemableAmount = interest - toReserveAmount;

            // Update the total borrows to reduce by the amount of principal that has
            // been paid off
            totalBorrows -= (repayAmount - interest);

            // Update the account borrows to reflect the repayment
            accountBorrows[borrower].principal = borrowedAmount - repayAmount;
            accountBorrows[borrower].interest = 0;

            // Call update locked on the userManager to lock this borrowers stakers. This function
            // will revert if the account does not have enough vouchers to cover the repay amount. ie
            // the borrower is trying to repay more than is locked (owed)
            IUserManager(userManager).updateLocked(borrower, (repayAmount - interest).toUint96(), false);

            if (isOverdue) {
                // For borrowers that are paying back overdue balances we need to update their
                // frozen balance and the global total frozen balance on the UserManager
                IUserManager(userManager).onRepayBorrow(borrower);
            }

            if (getBorrowed(borrower) == 0) {
                // If the principal is now 0 we can reset the last repaid block to 0.
                // which indicates that the borrower has no outstanding loans.
                accountBorrows[borrower].lastRepay = 0;
            } else {
                // Save the current block number as last repaid
                accountBorrows[borrower].lastRepay = getBlockNumber();
            }
        } else {
            // For repayments that don't pay off the minimum we just need to adjust the
            // global balances and reduce the amount of interest accrued for the borrower
            toReserveAmount = (repayAmount * reserveFactorMantissa) / WAD;
            toRedeemableAmount = repayAmount - toReserveAmount;
            accountBorrows[borrower].interest = interest - repayAmount;
        }

        totalReserves += toReserveAmount;
        totalRedeemable += toRedeemableAmount;

        accountBorrows[borrower].interestIndex = borrowIndex;

        // Transfer underlying token that have been repaid and then deposit
        // then in the asset manager so they can be distributed between the
        // underlying money markets
        IERC20Upgradeable(underlying).safeTransferFrom(payer, address(this), repayAmount);
        _depositToAssetManager(repayAmount);

        emit LogRepay(payer, borrower, repayAmount);
    }

    /**
     *  @dev Accrue interest
     *  @return Accrue interest finished
     */
    function accrueInterest() public override returns (bool) {
        uint256 borrowRate = borrowRatePerBlock();
        uint256 currentBlockNumber = getBlockNumber();
        uint256 blockDelta = currentBlockNumber - accrualBlockNumber;

        uint256 simpleInterestFactor = borrowRate * blockDelta;
        uint256 borrowIndexNew = (simpleInterestFactor * borrowIndex) / WAD + borrowIndex;

        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;

        return true;
    }

    function debtWriteOff(address borrower, uint256 amount) external override whenNotPaused onlyUserManager {
        if (amount == 0) revert AmountZero();

        uint256 oldPrincipal = getBorrowed(borrower);
        uint256 repayAmount = amount > oldPrincipal ? oldPrincipal : amount;

        accountBorrows[borrower].principal = oldPrincipal - repayAmount;
        totalBorrows -= repayAmount;

        if (repayAmount == oldPrincipal) {
            // If all principal is written off, we can reset the last repaid block to 0.
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
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 exchangeRate = exchangeRateStored();
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        assetToken.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 actualMintAmount = balanceAfter - balanceBefore;
        totalRedeemable += actualMintAmount;
        uint256 mintTokens = (actualMintAmount * WAD) / exchangeRate;
        _mint(msg.sender, mintTokens);

        _depositToAssetManager(actualMintAmount);

        emit LogMint(msg.sender, actualMintAmount, mintTokens);
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

        uint256 exchangeRate = exchangeRateStored();

        // Amount of the uToken to burn
        uint256 uTokenAmount;

        // Amount of the underlying token to redeem
        uint256 underlyingAmount;

        if (amountIn > 0) {
            // We calculate the exchange rate and the amount of underlying to be redeemed:
            // uTokenAmount = amountIn
            // underlyingAmount = amountIn x exchangeRateCurrent
            uTokenAmount = amountIn;
            underlyingAmount = (amountIn * exchangeRate) / WAD;
        } else {
            // We get the current exchange rate and calculate the amount to be redeemed:
            // uTokenAmount = amountOut / exchangeRate
            // underlyingAmount = amountOut
            uTokenAmount = (amountOut * WAD) / exchangeRate;
            underlyingAmount = amountOut;
        }

        uint256 remaining = IAssetManager(assetManager).withdraw(underlying, msg.sender, underlyingAmount);
        if (remaining > underlyingAmount) revert WithdrawFailed();
        uint256 actualAmount = underlyingAmount - remaining;
        totalRedeemable -= actualAmount;
        uint256 realUtokenAmount = (actualAmount * WAD) / exchangeRate;
        _burn(msg.sender, realUtokenAmount);
        emit LogRedeem(msg.sender, amountIn, amountOut, actualAmount);
    }

    /* -------------------------------------------------------------------
       Reserve Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Add tokens to the reseve
     * @param addAmount amount of tokens to add
     */
    function addReserves(uint256 addAmount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        assetToken.safeTransferFrom(msg.sender, address(this), addAmount);
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 actualAddAmount = balanceAfter - balanceBefore;

        totalReserves += actualAddAmount;

        _depositToAssetManager(balanceAfter);

        emit LogReservesAdded(msg.sender, actualAddAmount, totalReserves);
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
        if (reduceAmount > totalReserves) revert AmountError();
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 remaining = IAssetManager(assetManager).withdraw(underlying, receiver, reduceAmount);
        if (remaining > reduceAmount) revert WithdrawFailed();
        uint256 actualAmount = reduceAmount - remaining;
        totalReserves -= actualAmount;

        emit LogReservesReduced(receiver, actualAmount, totalReserves);
    }

    /* -------------------------------------------------------------------
       Internal Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Function to simply retrieve block number
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getBlockNumber() internal view returns (uint256) {
        return block.number;
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
