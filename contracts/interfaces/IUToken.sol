//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 *  @title UToken Interface
 *  @dev Union members can borrow and repay thru this component.
 */
interface IUToken {
    function setAssetManager(address assetManager) external;

    function setUserManager(address userManager) external;

    function exchangeRateStored() external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function overdueTime() external view returns (uint256);

    function getRemainingDebtCeiling() external view returns (uint256);

    function getBorrowed(address account) external view returns (uint256);

    function getLastRepay(address account) external view returns (uint256);

    function checkIsOverdue(address account) external view returns (bool);

    function borrowRatePerSecond() external view returns (uint256);

    function calculatingFee(uint256 amount) external view returns (uint256);

    function calculatingInterest(address account) external view returns (uint256);

    function borrowBalanceView(address account) external view returns (uint256);

    function setOriginationFee(uint256 originationFee_) external;

    function setDebtCeiling(uint256 debtCeiling_) external;

    function setMaxBorrow(uint256 maxBorrow_) external;

    function setMinBorrow(uint256 minBorrow_) external;

    function setOverdueTime(uint256 overdueBlocks_) external;

    function setInterestRateModel(address newInterestRateModel) external;

    function setReserveFactor(uint256 reserveFactorMantissa_) external;

    function supplyRatePerSecond() external returns (uint256);

    function accrueInterest() external returns (bool);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function mint(uint256 mintAmount) external;

    function redeem(uint256 amountIn, uint256 amountOut) external;

    function addReserves(uint256 addAmount) external;

    function removeReserves(address receiver, uint256 reduceAmount) external;

    function borrow(address to, uint256 amount) external;

    function repayInterest(address borrower) external;

    function repayBorrow(address borrower, uint256 amount) external;

    function debtWriteOff(address borrower, uint256 amount) external;

    function setMintFeeRate(uint256 newRate) external;
}
