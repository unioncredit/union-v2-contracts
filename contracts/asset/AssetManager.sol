//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Controller} from "../Controller.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {IMarketRegistry} from "../interfaces/IMarketRegistry.sol";
import {IMoneyMarketAdapter} from "../interfaces/IMoneyMarketAdapter.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 *  @title AssetManager
 *  @author Union
 *  @dev  Manage the token assets deposited by components and admins, and invest
 *        tokens to the integrated underlying lending protocols.
 */
contract AssetManager is Controller, ReentrancyGuardUpgradeable, IAssetManager {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    /* -------------------------------------------------------------------
      Storage 
    ------------------------------------------------------------------- */

    /**
     * @dev Address of market registry
     */
    address public marketRegistry;

    /**
     * @dev Withdraw Seuqence
     * @dev Priority sequence of money market indices for processing withdraws
     */
    uint256[] public withdrawSeq;

    /**
     * @dev Record admin or userManager balance
     * @dev Maps user to token to balance
     */
    mapping(address => mapping(address => uint256)) public balances;

    /**
     * @dev Total balance of a token
     * @dev Maps token to balance (deposited)
     */
    mapping(address => uint256) public totalPrincipal;

    /**
     * @dev Supported markets
     * @dev Mapping of tokens to boolean (isSupported)
     */
    mapping(address => bool) public supportedMarkets;

    /**
     * @dev Money Market Adapters
     */
    IMoneyMarketAdapter[] public moneyMarkets;

    /**
     * @dev Supported tokens
     */
    address[] public supportedTokensList;

    /* -------------------------------------------------------------------
      Events 
    ------------------------------------------------------------------- */

    /**
     *  @dev Emit when making a deposit
     *  @param token Depositing token address
     *  @param account Account address
     *  @param amount Deposit amount, in wei
     */
    event LogDeposit(address indexed token, address indexed account, uint256 amount);
    /**
     *  @dev Emit when withdrawing from AssetManager
     *  @param token Depositing token address
     *  @param account Account address
     *  @param amount Withdraw amount, in wei
     *  @param remaining The amount cannot be withdrawn
     */
    event LogWithdraw(address indexed token, address indexed account, uint256 amount, uint256 remaining);
    /**
     *  @dev Emit when rebalancing among the integrated money markets
     *  @param tokenAddress The address of the token to be rebalanced
     *  @param percentages Array of the percentages of the tokens to deposit to the money markets
     */
    event LogRebalance(address tokenAddress, uint256[] percentages);

    /* -------------------------------------------------------------------
      Errors 
    ------------------------------------------------------------------- */

    error UnsupportedToken();
    error AuthFailed();
    error NotParity();
    error AmountZero();
    error InsufficientBalance();
    error TokenExists();
    error RemainingFunds();

    /* -------------------------------------------------------------------
      Constructor/Initializer 
    ------------------------------------------------------------------- */

    function __AssetManager_init(address admin, address _marketRegistry) external initializer {
        Controller.__Controller_init(admin);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        marketRegistry = _marketRegistry;
    }

    /* -------------------------------------------------------------------
      Modifiers 
    ------------------------------------------------------------------- */

    modifier checkMarketSupported(address token) {
        if (!isMarketSupported(token)) revert UnsupportedToken();
        _;
    }

    modifier onlyAuth(address token) {
        if (!(_isUToken(msg.sender, token) || _isUserManager(msg.sender, token))) revert AuthFailed();
        _;
    }

    /* -------------------------------------------------------------------
      Setters 
    ------------------------------------------------------------------- */

    function setMarketRegistry(address _marketRegistry) external onlyAdmin {
        marketRegistry = _marketRegistry;
    }

    /**
     *  @dev Set withdraw sequence
     *  @param newSeq priority sequence of money market indices to be used while withdrawing
     */
    function setWithdrawSequence(uint256[] calldata newSeq) external override onlyAdmin {
        if (newSeq.length != moneyMarkets.length) revert NotParity();
        withdrawSeq = newSeq;
    }

    /* -------------------------------------------------------------------
      View Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev Get the balance of asset manager, plus the total amount of tokens deposited to all the underlying lending protocols
     *  @param tokenAddress ERC20 token address
     *  @return Pool balance
     */
    function getPoolBalance(address tokenAddress) public view override returns (uint256) {
        IERC20Upgradeable poolToken = IERC20Upgradeable(tokenAddress);
        uint256 balance = poolToken.balanceOf(address(this));
        if (isMarketSupported(tokenAddress)) {
            return totalSupplyView(tokenAddress) + balance;
        } else {
            return balance;
        }
    }

    /**
     *  @dev Returns the amount of the lending pool balance minus the amount of total staked.
     *  @param tokenAddress ERC20 token address
     *  @return loanAmount Amount can be borrowed
     */
    function getLoanableAmount(address tokenAddress) public view override returns (uint256) {
        uint256 poolBalance = getPoolBalance(tokenAddress);
        return poolBalance > totalPrincipal[tokenAddress] ? poolBalance - totalPrincipal[tokenAddress] : 0;
    }

    /**
     *  @dev Get the total amount of tokens deposited to all the integrated underlying protocols without side effects.
     *  @param tokenAddress ERC20 token address
     *  @return tokenSupply Total market balance
     */
    function totalSupply(address tokenAddress) external override returns (uint256) {
        uint256 tokenSupply = 0;
        if (isMarketSupported(tokenAddress)) {
            uint256 moneyMarketsLength = moneyMarkets.length;
            for (uint256 i = 0; i < moneyMarketsLength; i++) {
                if (moneyMarkets[i].supportsToken(tokenAddress)) {
                    tokenSupply += moneyMarkets[i].getSupply(tokenAddress);
                }
            }
        }
        return tokenSupply;
    }

    /**
     *  @dev Get the total amount of tokens deposited to all the integrated underlying protocols, but without side effects. Safe to call anytime, but may not get the most updated number for the current block. Call totalSupply() for that purpose.
     *  @param tokenAddress ERC20 token address
     *  @return tokenSupply Total market balance
     */
    function totalSupplyView(address tokenAddress) public view override returns (uint256) {
        uint256 tokenSupply = 0;
        if (isMarketSupported(tokenAddress)) {
            uint256 moneyMarketsLength = moneyMarkets.length;
            for (uint256 i = 0; i < moneyMarketsLength; i++) {
                if (moneyMarkets[i].supportsToken(tokenAddress)) {
                    tokenSupply += moneyMarkets[i].getSupplyView(tokenAddress);
                }
            }
        }
        return tokenSupply;
    }

    /**
     *  @dev Check if there is an underlying protocol available for the given ERC20 token.
     *  @param tokenAddress ERC20 token address
     *  @return Whether is supported
     */
    function isMarketSupported(address tokenAddress) public view override returns (bool) {
        return supportedMarkets[tokenAddress];
    }

    /**
     *  @dev Get the number of supported underlying protocols.
     *  @return MoneyMarkets length
     */
    function moneyMarketsCount() external view override returns (uint256) {
        return moneyMarkets.length;
    }

    /**
     *  @dev Get the count of supported tokens
     *  @return Number of supported tokens
     */
    function supportedTokensCount() external view override returns (uint256) {
        return supportedTokensList.length;
    }

    /**
     *  @dev Get the supported lending protocol
     *  @param tokenAddress ERC20 token address
     *  @param marketId MoneyMarkets array index
     *  @return rate tokenSupply, rate(compound is supplyRatePerBlock 1e18, aave is supplyRatePerYear 1e27)
     */
    function getMoneyMarket(
        address tokenAddress,
        uint256 marketId
    ) external view override returns (uint256 rate, uint256 tokenSupply) {
        rate = moneyMarkets[marketId].getRate(tokenAddress);
        tokenSupply += moneyMarkets[marketId].getSupplyView(tokenAddress);
    }

    /* -------------------------------------------------------------------
      Core Functions 
    ------------------------------------------------------------------- */

    /**
     *  @dev  Deposit tokens to AssetManager, and those tokens will be passed along to
     *        adapters to deposit to integrated asset protocols if any is available.
     *  @param token ERC20 token address
     *  @param amount ERC20 token address
     *  @return Deposited amount
     */
    function deposit(
        address token,
        uint256 amount
    ) external override whenNotPaused onlyAuth(token) nonReentrant returns (bool) {
        IERC20Upgradeable poolToken = IERC20Upgradeable(token);
        if (amount == 0) revert AmountZero();

        if (!_isUToken(msg.sender, token)) {
            balances[msg.sender][token] += amount;
            totalPrincipal[token] += amount;
        }

        bool remaining = true;
        poolToken.safeTransferFrom(msg.sender, address(this), amount);
        if (isMarketSupported(token)) {
            uint256 moneyMarketsLength = moneyMarkets.length;
            // assumption: markets are arranged in order of decreasing liquidity
            // iterate markets till floors are filled
            // floors define minimum amount to maintain confidence in liquidity
            for (uint256 i = 0; i < moneyMarketsLength && remaining; i++) {
                IMoneyMarketAdapter moneyMarket = moneyMarkets[i];

                if (!moneyMarket.supportsToken(token)) continue;
                if (moneyMarket.floorMap(token) <= moneyMarket.getSupply(token)) continue;

                poolToken.safeTransfer(address(moneyMarket), amount);
                if (moneyMarket.deposit(token)) {
                    remaining = false;
                }
            }

            // assumption: less liquid markets provide more yield
            // iterate markets in reverse to optimize for yield
            // do this only if floors are filled i.e. min liquidity satisfied
            // deposit in the market where ceiling is not being exceeded
            for (uint256 j = moneyMarketsLength; j > 0 && remaining; j--) {
                IMoneyMarketAdapter moneyMarket = moneyMarkets[j - 1];
                if (!moneyMarket.supportsToken(token)) continue;

                uint256 supply = moneyMarket.getSupply(token);
                uint256 ceiling = moneyMarket.ceilingMap(token);
                if (supply + amount > ceiling) continue;

                poolToken.safeTransfer(address(moneyMarket), amount);
                if (moneyMarket.deposit(token)) {
                    remaining = false;
                }
            }
        }

        emit LogDeposit(token, msg.sender, amount);
        return true;
    }

    /**
     *  @dev Withdraw from AssetManager
     *  @param token ERC20 token address
     *  @param account User address
     *  @param amount ERC20 token address
     *  @return Withdraw amount
     */
    function withdraw(
        address token,
        address account,
        uint256 amount
    ) external override whenNotPaused nonReentrant onlyAuth(token) returns (uint256) {
        if (!_checkSenderBalance(msg.sender, token, amount)) revert InsufficientBalance();

        uint256 remaining = amount;

        // If there are tokens in Asset Manager then transfer them on priority
        uint256 selfBalance = IERC20Upgradeable(token).balanceOf(address(this));
        if (selfBalance > 0) {
            uint256 withdrawAmount = selfBalance < remaining ? selfBalance : remaining;
            remaining -= withdrawAmount;
            IERC20Upgradeable(token).safeTransfer(account, withdrawAmount);
        }

        if (isMarketSupported(token)) {
            uint256 withdrawSeqLength = withdrawSeq.length;
            // iterate markets according to defined sequence and withdraw
            for (uint256 i = 0; i < withdrawSeqLength && remaining > 0; i++) {
                IMoneyMarketAdapter moneyMarket = moneyMarkets[withdrawSeq[i]];
                if (!moneyMarket.supportsToken(token)) continue;

                uint256 supply = moneyMarket.getSupply(token);
                if (supply == 0) continue;

                uint256 withdrawAmount = supply < remaining ? supply : remaining;
                if (moneyMarket.withdraw(token, account, withdrawAmount)) {
                    remaining -= withdrawAmount;
                }
            }
        }

        if (!_isUToken(msg.sender, token)) {
            balances[msg.sender][token] = balances[msg.sender][token] - amount + remaining;
            totalPrincipal[token] = totalPrincipal[token] - amount + remaining;
        }

        emit LogWithdraw(token, account, amount, remaining);

        return remaining;
    }

    /**
     * @dev Write of Debt
     */
    function debtWriteOff(address token, uint256 amount) external override {
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();
        balances[msg.sender][token] -= amount;
        totalPrincipal[token] -= amount;
    }

    /**
     *  @dev Add a new ERC20 token to support in AssetManager
     *  @param tokenAddress ERC20 token address
     */
    function addToken(address tokenAddress) external override onlyAdmin {
        if (supportedMarkets[tokenAddress]) revert TokenExists();
        supportedTokensList.push(tokenAddress);
        supportedMarkets[tokenAddress] = true;

        approveAllMarketsMax(tokenAddress);
    }

    /**
     *  @dev Remove a ERC20 token to support in AssetManager
     *  @param tokenAddress ERC20 token address
     */
    function removeToken(address tokenAddress) external override onlyAdmin {
        bool isExist = false;
        uint256 index = 0;
        uint256 supportedTokensLength = supportedTokensList.length;

        for (uint256 i = 0; i < supportedTokensLength; i++) {
            if (tokenAddress == address(supportedTokensList[i])) {
                isExist = true;
                index = i;
                break;
            }
        }

        if (isExist) {
            for (uint256 i = 0; i < moneyMarkets.length; i++) {
                if (moneyMarkets[i].getSupply(tokenAddress) >= 10000) revert RemainingFunds(); //ignore the dust
            }

            supportedTokensList[index] = supportedTokensList[supportedTokensLength - 1];
            supportedTokensList.pop();
            supportedMarkets[tokenAddress] = false;
            _removeMarketsApprovals(IERC20Upgradeable(tokenAddress));
        }
    }

    /**
     *  @dev Add a new adapter for the underlying lending protocol
     *  @param adapterAddress adapter address
     */
    function addAdapter(address adapterAddress) external override onlyAdmin {
        bool isExist = false;
        uint256 moneyMarketsLength = moneyMarkets.length;

        for (uint256 i = 0; i < moneyMarketsLength; i++) {
            if (adapterAddress == address(moneyMarkets[i])) isExist = true;
        }

        if (!isExist) {
            moneyMarkets.push(IMoneyMarketAdapter(adapterAddress));
            withdrawSeq.push(moneyMarkets.length - 1);
        }

        approveAllTokensMax(adapterAddress);
    }

    /**
     *  @dev Remove a adapter for the underlying lending protocol
     *  @param adapterAddress adapter address
     */
    function removeAdapter(address adapterAddress) external override onlyAdmin {
        bool isExist = false;
        uint256 index = 0;
        uint256 moneyMarketsLength = moneyMarkets.length;
        for (uint256 i = 0; i < moneyMarketsLength; i++) {
            if (adapterAddress == address(moneyMarkets[i])) {
                isExist = true;
                index = i;
                break;
            }
        }

        if (isExist) {
            for (uint256 i = 0; i < supportedTokensList.length; i++) {
                if (moneyMarkets[index].getSupply(supportedTokensList[i]) >= 10000) revert RemainingFunds(); //ignore the dust
            }
            moneyMarkets[index] = moneyMarkets[moneyMarketsLength - 1];
            moneyMarkets.pop();

            withdrawSeq[index] = withdrawSeq[withdrawSeq.length - 1];
            withdrawSeq.pop();

            _removeTokenApprovals(adapterAddress);
        }
    }

    /**
     *  @dev For a give token set allowance for all integrated money markets
     *  @param tokenAddress ERC20 token address
     */
    function approveAllMarketsMax(address tokenAddress) public override onlyAdmin {
        IERC20Upgradeable poolToken = IERC20Upgradeable(tokenAddress);
        uint256 moneyMarketsLength = moneyMarkets.length;
        for (uint256 i = 0; i < moneyMarketsLength; i++) {
            _increaseAllowance(poolToken, address(moneyMarkets[i]), type(uint256).max);
        }
    }

    /**
     *  @dev For a give moeny market set allowance for all underlying tokens
     *  @param adapterAddress Address of adaptor for money market
     */
    function approveAllTokensMax(address adapterAddress) public override onlyAdmin {
        uint256 supportedTokensLength = supportedTokensList.length;
        for (uint256 i = 0; i < supportedTokensLength; i++) {
            IERC20Upgradeable poolToken = IERC20Upgradeable(supportedTokensList[i]);
            _increaseAllowance(poolToken, adapterAddress, type(uint256).max);
        }
    }

    /**
     * @dev Take all the supply of `tokenAddress` and redistribute it according to `percentages`.
     *
     * Rejects if the token is not supported.
     *
     * @param tokenAddress Address of the token that is going to be rebalanced
     * @param percentages A list of percentages, expressed as units in 10000, indicating how to deposit the tokens in
     * each underlying money market. The length of this array is one less than the amount of money markets: the last
     * money market will receive the remaining tokens. For example, if there are 3 money markets, and you want to
     * rebalance so that the first one has 10.5% of the tokens, the second one 55%, and the third one 34.5%, this param
     * will be [1050, 5500].
     */
    function rebalance(
        address tokenAddress,
        uint256[] calldata percentages
    ) external override onlyAdmin checkMarketSupported(tokenAddress) {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        uint256 moneyMarketsLength = moneyMarkets.length;
        uint256 percentagesLength = percentages.length;

        IMoneyMarketAdapter[] memory supportedMoneyMarkets = new IMoneyMarketAdapter[](moneyMarketsLength);
        uint256 supportedMoneyMarketsSize;

        // Loop through each money market and withdraw all the tokens
        for (uint256 i = 0; i < moneyMarketsLength; i++) {
            IMoneyMarketAdapter moneyMarket = moneyMarkets[i];
            if (!moneyMarket.supportsToken(tokenAddress)) continue;
            supportedMoneyMarkets[supportedMoneyMarketsSize] = moneyMarket;
            supportedMoneyMarketsSize++;
            moneyMarket.withdrawAll(tokenAddress, address(this));
        }

        if (percentagesLength + 1 != supportedMoneyMarketsSize) revert NotParity();

        uint256 tokenSupply = token.balanceOf(address(this));

        for (uint256 i = 0; i < percentagesLength; i++) {
            IMoneyMarketAdapter moneyMarket = supportedMoneyMarkets[i];
            uint256 amountToDeposit = (tokenSupply * percentages[i]) / 10000;
            if (amountToDeposit == 0) continue;
            token.safeTransfer(address(moneyMarket), amountToDeposit);
            moneyMarket.deposit(tokenAddress);
        }

        uint256 remainingTokens = token.balanceOf(address(this));

        IMoneyMarketAdapter lastMoneyMarket = supportedMoneyMarkets[supportedMoneyMarketsSize - 1];
        if (remainingTokens > 0) {
            token.safeTransfer(address(lastMoneyMarket), remainingTokens);
            lastMoneyMarket.deposit(tokenAddress);
        }

        emit LogRebalance(tokenAddress, percentages);
    }

    /* -------------------------------------------------------------------
      Internal Functions 
    ------------------------------------------------------------------- */

    function _checkSenderBalance(address sender, address tokenAddress, uint256 amount) private view returns (bool) {
        if (_isUToken(sender, tokenAddress)) {
            // For all the lending markets, which have no deposits, return the tokens from the pool
            return getLoanableAmount(tokenAddress) >= amount;
        }

        return balances[sender][tokenAddress] >= amount;
    }

    function _isUToken(address sender, address token) private view returns (bool) {
        return IMarketRegistry(marketRegistry).uTokens(token) == sender;
    }

    function _isUserManager(address sender, address token) private view returns (bool) {
        return IMarketRegistry(marketRegistry).userManagers(token) == sender;
    }

    function _increaseAllowance(IERC20Upgradeable token, address spender, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < amount) {
            token.safeIncreaseAllowance(spender, amount - currentAllowance);
        }
    }

    /**
     *  @dev For a give token set allowance for all integrated money markets
     *  @param poolToken ERC20 token address
     */
    function _removeMarketsApprovals(IERC20Upgradeable poolToken) private {
        uint256 moneyMarketsLength = moneyMarkets.length;
        for (uint256 i = 0; i < moneyMarketsLength; i++) {
            uint256 currentAllowance = poolToken.allowance(address(this), address(moneyMarkets[i]));
            poolToken.safeDecreaseAllowance(address(moneyMarkets[i]), currentAllowance);
        }
    }

    /**
     *  @dev For a give moeny market set allowance for all underlying tokens
     *  @param adapterAddress Address of adaptor for money market
     */
    function _removeTokenApprovals(address adapterAddress) private {
        uint256 supportedTokensLength = supportedTokensList.length;
        for (uint256 i = 0; i < supportedTokensLength; i++) {
            IERC20Upgradeable poolToken = IERC20Upgradeable(supportedTokensList[i]);
            uint256 currentAllowance = poolToken.allowance(address(this), adapterAddress);
            poolToken.safeDecreaseAllowance(adapterAddress, currentAllowance);
        }
    }
}
