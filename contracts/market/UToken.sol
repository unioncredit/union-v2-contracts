//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../Controller.sol";
import "../interfaces/IUserManager.sol";
import "../interfaces/IAssetManager.sol";
import "../interfaces/IUToken.sol";
import "../interfaces/IInterestRateModel.sol";

/**
 *  @title UToken Contract
 *  @dev Union accountBorrows can borrow and repay thru this component.
 */
contract UToken is IUToken, Controller, ERC20PermitUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

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
     *  @dev Total amount of reserves of the underlying held in this marke
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
    error AddressZero();
    error AmountExceedGlobalMax();
    error AmountExceedMaxBorrow();
    error AmountLessMinBorrow();
    error AmountZero();
    error BorrowRateExceedLimit();
    error WithdrawFailed();
    error CallerNotMember();
    error CallerNotUserManager();
    error ContractNotInterestModel();
    error InitExchangeRateNotZero();
    error InsufficientFundsLeft();
    error MemberIsOverdue();
    error ReserveFactoryExceedLimit();
    error DepositToAssetManagerFailed();

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
    event LogRedeem(address redeemer, uint256 redeemTokensIn, uint256 redeemAmountIn, uint256 redeemAmount);

    /**
     *  @dev Token added to the reserves
     *  @param reserver address of sender that added to reservers
     *  @param actualAddAmount amount of tokens added
     *  @param totalReservesNew new total reserve amount
     */
    event LogReservesAdded(address reserver, uint256 actualAddAmount, uint256 totalReservesNew);

    /**
     *  @dev Token removed from the reserves
     *  @param receiver reciever address of tokens
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
    event LogBorrow(address indexed account, uint256 amount, uint256 fee);

    /**
     *  @dev Event repay
     *  @param account Member address
     *  @param amount Repay amount
     */
    event LogRepay(address indexed account, uint256 amount);

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
        uint256 debtCeiling_,
        uint256 maxBorrow_,
        uint256 minBorrow_,
        uint256 overdueBlocks_,
        address admin_
    ) public initializer {
        if (initialExchangeRateMantissa_ == 0) revert InitExchangeRateNotZero();
        if (address(underlying_) == address(0)) revert AddressZero();
        if (reserveFactorMantissa_ > RESERVE_FACTORY_MAX_MANTISSA) revert ReserveFactoryExceedLimit();
        Controller.__Controller_init(admin_);
        ERC20Upgradeable.__ERC20_init(name_, symbol_);
        ERC20PermitUpgradeable.__ERC20Permit_init(name_);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        underlying = underlying_;
        originationFee = originationFee_;
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
        if (assetManager_ == address(0)) revert AddressZero();
        assetManager = assetManager_;
    }

    /**
     *  @dev set User Manager contract address
     *  Accept claims only from the admin
     */
    function setUserManager(address userManager_) external onlyAdmin {
        if (userManager_ == address(0)) revert AddressZero();
        userManager = userManager_;
    }

    /**
     *  @dev Change loan origination fee value
     *  Accept claims only from the admin
     *  @param originationFee_ Fees deducted for each loan transaction
     */
    function setOriginationFee(uint256 originationFee_) external override onlyAdmin {
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
        if (newInterestRateModel_ == address(0)) revert AddressZero();
        address oldInterestRateModel = address(interestRateModel);
        address newInterestRateModel = newInterestRateModel_;
        if (!IInterestRateModel(newInterestRateModel).isInterestRateModel()) revert ContractNotInterestModel();
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
     *  @dev Get member interest index
     *  @param account Member address
     *  @return interestIndex
     */
    function getInterestIndex(address account) public view override returns (uint256) {
        return accountBorrows[account].interestIndex;
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
    function supplyRatePerBlock() public view override returns (uint256) {
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
    function balanceOfUnderlying(address owner) external override returns (uint256) {
        return exchangeRateCurrent() * balanceOf(owner);
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
    function borrow(uint256 amount) external override onlyMember(msg.sender) whenNotPaused nonReentrant {
        IAssetManager assetManagerContract = IAssetManager(assetManager);
        if (amount < minBorrow) revert AmountLessMinBorrow();
        if (amount > getRemainingDebtCeiling()) revert AmountExceedGlobalMax();

        uint256 fee = calculatingFee(amount);
        if (borrowBalanceView(msg.sender) + amount + fee > maxBorrow) revert AmountExceedMaxBorrow();
        if (checkIsOverdue(msg.sender)) revert MemberIsOverdue();
        if (amount > assetManagerContract.getLoanableAmount(underlying)) revert InsufficientFundsLeft();
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 borrowedAmount = borrowBalanceStoredInternal(msg.sender);

        //Set lastRepay init data
        if (getLastRepay(msg.sender) == 0) {
            accountBorrows[msg.sender].lastRepay = getBlockNumber();
        }

        uint256 accountBorrowsNew = borrowedAmount + amount + fee;
        uint256 totalBorrowsNew = totalBorrows + amount + fee;

        accountBorrows[msg.sender].principal += amount + fee;
        uint256 newPrincipal = getBorrowed(msg.sender);
        accountBorrows[msg.sender].interest = accountBorrowsNew - newPrincipal;
        accountBorrows[msg.sender].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        // The origination fees contribute to the reserve
        totalReserves += fee;

        if (!assetManagerContract.withdraw(underlying, msg.sender, amount)) revert WithdrawFailed();
        // TODO: this could overflow? should borrow input be uint96?
        IUserManager(userManager).updateLocked(msg.sender, uint96(amount + fee), true);

        emit LogBorrow(msg.sender, amount, fee);
    }

    /**
     * @dev Repay borrow see _repayBorrowFresh
     */
    function repayBorrow(uint256 repayAmount) external override whenNotPaused nonReentrant {
        _repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }

    /**
     * @dev Repay borrow see _repayBorrowFresh
     */
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external override whenNotPaused nonReentrant {
        _repayBorrowFresh(msg.sender, borrower, repayAmount);
    }

    /**
     *  @dev Repay the loan
     *  Accept claims only from the member
     *  Updated member lastPaymentEpoch only when the repayment amount is greater than interest
     *  @param payer Payer address
     *  @param borrower Borrower address
     *  @param amount Repay amount
     */
    function _repayBorrowFresh(
        address payer,
        address borrower,
        uint256 amount
    ) internal {
        if (!accrueInterest()) revert AccrueInterestFailed();

        uint256 interest = calculatingInterest(borrower);
        uint256 borrowedAmount = borrowBalanceStoredInternal(borrower);
        uint256 repayAmount = amount > borrowedAmount ? borrowedAmount : amount;
        if (repayAmount == 0) revert AmountZero();

        uint256 toReserveAmount;
        uint256 toRedeemableAmount;
        if (repayAmount >= interest) {
            toReserveAmount = (interest * reserveFactorMantissa) / WAD;
            toRedeemableAmount = interest - toReserveAmount;
            accountBorrows[borrower].principal = borrowedAmount - repayAmount;
            accountBorrows[borrower].interest = 0;

            if (getBorrowed(borrower) == 0) {
                //LastRepay is cleared when the arrears are paid off, and reinitialized the next time the loan is borrowed
                accountBorrows[borrower].lastRepay = 0;
            } else {
                accountBorrows[borrower].lastRepay = getBlockNumber();
            }

            IUserManager(userManager).updateLocked(borrower, uint96(repayAmount - interest), false);
        } else {
            toReserveAmount = (repayAmount * reserveFactorMantissa) / WAD;
            toRedeemableAmount = repayAmount - toReserveAmount;
            accountBorrows[borrower].interest = interest - repayAmount;
        }

        totalReserves += toReserveAmount;
        totalRedeemable += toRedeemableAmount;

        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows -= repayAmount;

        IERC20Upgradeable(underlying).safeTransferFrom(payer, address(this), repayAmount);

        _depositToAssetManager(repayAmount);

        emit LogRepay(borrower, repayAmount);
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
        uint256 interestAccumulated = (simpleInterestFactor * totalBorrows) / WAD;
        uint256 totalBorrowsNew = interestAccumulated + totalBorrows;
        uint256 borrowIndexNew = (simpleInterestFactor * borrowIndex) / WAD + borrowIndex;

        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;

        return true;
    }

    function debtWriteOff(address borrower, uint256 amount) external override whenNotPaused onlyUserManager {
        uint256 oldPrincipal = getBorrowed(borrower);
        uint256 repayAmount = amount > oldPrincipal ? oldPrincipal : amount;

        accountBorrows[borrower].principal = oldPrincipal - repayAmount;
        totalBorrows -= repayAmount;
    }

    /* -------------------------------------------------------------------
       Mint uToken Functions 
    ------------------------------------------------------------------- */

    /**
     * @dev Mint uTokens by depositing tokens
     * @param mintAmount Amount of uTokens to mint
     */
    function mint(uint256 mintAmount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        uint256 exchangeRate = exchangeRateStored();
        IERC20Upgradeable assetToken = IERC20Upgradeable(underlying);
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        assetToken.safeTransferFrom(msg.sender, address(this), mintAmount);
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 actualMintAmount = balanceAfter - balanceBefore;
        totalRedeemable += actualMintAmount;
        uint256 mintTokens = (actualMintAmount * WAD) / exchangeRate;
        _mint(msg.sender, mintTokens);

        _depositToAssetManager(actualMintAmount);

        emit LogMint(msg.sender, actualMintAmount, mintTokens);
    }

    /**
     * @notice Sender redeems uTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of uTokens to redeem into underlying
     */
    function redeem(uint256 redeemTokens) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        _redeemFresh(payable(msg.sender), redeemTokens, 0);
    }

    /**
     * @notice Sender redeems uTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to receive from redeeming uTokens
     */
    function redeemUnderlying(uint256 redeemAmount) external override whenNotPaused nonReentrant {
        if (!accrueInterest()) revert AccrueInterestFailed();
        _redeemFresh(payable(msg.sender), 0, redeemAmount);
    }

    /**
     * @notice User redeems uTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of uTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming uTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     */
    function _redeemFresh(
        address payable redeemer,
        uint256 redeemTokensIn,
        uint256 redeemAmountIn
    ) private {
        if (redeemTokensIn != 0 && redeemAmountIn != 0) revert AmountZero();

        IAssetManager assetManagerContract = IAssetManager(assetManager);

        uint256 exchangeRate = exchangeRateStored();

        uint256 redeemTokens;
        uint256 redeemAmount;

        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            redeemTokens = redeemTokensIn;
            redeemAmount = (redeemTokensIn * exchangeRate) / WAD;
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */
            redeemTokens = (redeemAmountIn * WAD) / exchangeRate;
            redeemAmount = redeemAmountIn;
        }

        totalRedeemable -= redeemAmount;
        _burn(redeemer, redeemTokens);
        if (!assetManagerContract.withdraw(underlying, redeemer, redeemAmount)) revert WithdrawFailed();

        emit LogRedeem(redeemer, redeemTokensIn, redeemAmountIn, redeemAmount);
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
     * @dev Remove tokens to the reseve
     * @param receiver address to recieve tokens
     * @param reduceAmount amount of tokens to remove
     */
    function removeReserves(address receiver, uint256 reduceAmount)
        external
        override
        whenNotPaused
        nonReentrant
        onlyAdmin
    {
        if (!accrueInterest()) revert AccrueInterestFailed();

        totalReserves -= reduceAmount;

        if (!IAssetManager(assetManager).withdraw(underlying, receiver, reduceAmount)) revert WithdrawFailed();

        emit LogReservesReduced(receiver, reduceAmount, totalReserves);
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
        assetToken.safeApprove(assetManager, 0); // Some ERC20 tokens (e.g. Tether) changed the behavior of approve to look like safeApprove
        assetToken.safeApprove(assetManager, amount);
        if (!IAssetManager(assetManager).deposit(underlying, amount)) revert DepositToAssetManagerFailed();
    }
}
