import {BigNumber, BigNumberish, ContractTransaction, Signer} from "ethers";
import {ethers} from "hardhat";
import {Contracts} from "../../deploy";

export const roll = async (n: number) => {
    await Promise.all(
        [...Array(n).keys()].map(async () => {
            await ethers.provider.send("evm_mine", []);
        })
    );
};

export const warp = async (seconds: number) => {
    await ethers.provider.send("evm_increaseTime", [seconds]);
    await ethers.provider.send("evm_mine", []);
};

export interface Helpers {
    getStakedAmounts: (...args: Signer[]) => Promise<BigNumber[]>;
    calculateRewards: (...args: Signer[]) => Promise<BigNumber[]>;
    getRewardsMultipliers: (...args: Signer[]) => Promise<BigNumber[]>;
    getVouchingAmounts: (borrower: Signer, ...args: Signer[]) => Promise<BigNumber[]>;
    getCreditLimits: (...args: Signer[]) => Promise<BigNumber[]>;
    getVouch: (staker: Signer, borrower: Signer) => Promise<["string", BigNumberish, BigNumberish, BigNumberish]>;
    getVouchByIndex: (staker: Signer, index: number) => Promise<["string", BigNumberish, BigNumberish, BigNumberish]>;
    getBorrowed: (borrower: Signer) => Promise<BigNumberish[]>;
    borrowWithFee: (amount: BigNumber) => Promise<BigNumber>;
    updateTrust: (staker: Signer, borrower: Signer, amount: BigNumberish) => Promise<ContractTransaction>;
    cancelVouch: (staker: Signer, borrower: Signer, from?: Signer) => Promise<ContractTransaction>;
    borrow: (borrower: Signer, amount: BigNumberish) => Promise<ContractTransaction>;
    repay: (borrower: Signer, amount: BigNumberish) => Promise<ContractTransaction>;
    repayFull: (borrower: Signer) => Promise<ContractTransaction>;
    stake: (amount: BigNumberish, ...accounts: Signer[]) => Promise<void>;
    withOverdueblocks: (blocks: BigNumberish, fn: () => Promise<void>) => Promise<void>;
}

export const createHelpers = (contracts: Contracts): Helpers => {
    /** ---------------------------------------------------------
     * View Functions
     * ------------------------------------------------------- */

    const getStakedAmounts = (...accounts: Signer[]) => {
        return Promise.all(
            accounts.map(async account => {
                const address = await account.getAddress();
                return contracts.userManager.getStakerBalance(address);
            })
        );
    };

    const calculateRewards = (...accounts: Signer[]) => {
        return Promise.all(
            accounts.map(async account => {
                const address = await account.getAddress();
                return contracts.comptroller.calculateRewards(address, contracts.dai.address);
            })
        );
    };

    const getRewardsMultipliers = (...accounts: Signer[]) => {
        return Promise.all(
            accounts.map(async account => {
                const address = await account.getAddress();
                return contracts.comptroller.getRewardsMultiplier(address, contracts.dai.address);
            })
        );
    };

    const getVouchingAmounts = (borrower: Signer, ...accounts: Signer[]) => {
        const borrowerAddress = borrower.getAddress();
        return Promise.all(
            accounts.map(async account => {
                const address = await account.getAddress();
                return contracts.userManager.getVouchingAmount(address, borrowerAddress);
            })
        );
    };

    const getCreditLimits = (...accounts: Signer[]) => {
        return Promise.all(
            accounts.map(async account => {
                const address = await account.getAddress();
                return contracts.userManager.getCreditLimit(address);
            })
        );
    };

    const getVouch = async (staker: Signer, borrower: Signer) => {
        const borrowerAddress = await borrower.getAddress();
        const stakerAddress = await staker.getAddress();
        const [, index] = await contracts.userManager.voucherIndexes(borrowerAddress, stakerAddress);
        const [s, amount, locked, lastUpdate] = await contracts.userManager.vouchers(borrowerAddress, index);
        return [s, amount, locked, lastUpdate] as ["string", BigNumberish, BigNumberish, BigNumberish];
    };

    const getVouchByIndex = async (borrower: Signer, index: number) => {
        const borrowerAddress = await borrower.getAddress();
        const [s, amount, locked, lastUpdate] = await contracts.userManager.vouchers(borrowerAddress, index);
        return [s, amount, locked, lastUpdate] as ["string", BigNumberish, BigNumberish, BigNumberish];
    };

    const borrowWithFee = async (amount: BigNumber) => {
        const originationFee = await contracts.uToken.originationFee();
        const WAD = await contracts.uToken.WAD();
        return amount.add(amount.mul(originationFee).div(WAD));
    };

    const getBorrowed = async (borrower: Signer) => {
        const borrowerAddress = await borrower.getAddress();
        const lastRepay = await contracts.uToken.getLastRepay(borrowerAddress);
        const borrowed = await contracts.uToken.getBorrowed(borrowerAddress);
        return [lastRepay, borrowed];
    };

    /** ---------------------------------------------------------
     * Payable Functions
     * ------------------------------------------------------- */

    const updateTrust = async (staker: Signer, borrower: Signer, amount: BigNumberish) => {
        const borrowerAddress = await borrower.getAddress();
        return contracts.userManager.connect(staker).updateTrust(borrowerAddress, amount);
    };

    const cancelVouch = async (staker: Signer, borrower: Signer, from?: Signer) => {
        const stakerAddress = await staker.getAddress();
        const borrowerAddress = await borrower.getAddress();
        return contracts.userManager.connect(from || staker).cancelVouch(stakerAddress, borrowerAddress);
    };

    const borrow = async (borrower: Signer, amount: BigNumberish) => {
        return contracts.uToken.connect(borrower).borrow(amount);
    };

    const repay = async (borrower: Signer, amount: BigNumberish) => {
        const borrowerAddress = await borrower.getAddress();
        const daiBalance = await contracts.dai.balanceOf(borrowerAddress);
        if (daiBalance.lt(amount) && "mint" in contracts.dai) {
            await contracts.dai.mint(borrowerAddress, amount);
        }
        await contracts.dai.connect(borrower).approve(contracts.uToken.address, ethers.constants.MaxUint256);
        return contracts.uToken.connect(borrower).repayBorrow(amount);
    };

    const repayFull = async (borrower: Signer) => {
        const borrowerAddress = await borrower.getAddress();
        const owed = await contracts.uToken.borrowBalanceView(borrowerAddress);
        const daiBalance = await contracts.dai.balanceOf(borrowerAddress);
        if (daiBalance.lt(owed) && "mint" in contracts.dai) {
            await contracts.dai.mint(borrowerAddress, owed.mul(1100).div(1000));
        }
        await contracts.dai.connect(borrower).approve(contracts.uToken.address, ethers.constants.MaxUint256);
        return contracts.uToken.connect(borrower).repayBorrow(ethers.constants.MaxUint256);
    };

    const stake = async (stakeAmount: BigNumberish, ...accounts: Signer[]) => {
        await Promise.all(
            accounts.map(account => {
                return contracts.userManager.connect(account).stake(stakeAmount);
            })
        );
    };

    /** ---------------------------------------------------------
     * Higher Order
     * ------------------------------------------------------- */

    const withOverdueblocks = async (blocks: BigNumberish, fn: () => Promise<void>) => {
        const overdueBlocks = await contracts.uToken.overdueBlocks();
        await contracts.uToken.setOverdueBlocks(blocks);
        await fn();
        await contracts.uToken.setOverdueBlocks(overdueBlocks);
    };

    return {
        getStakedAmounts,
        calculateRewards,
        getVouchingAmounts,
        getRewardsMultipliers,
        getCreditLimits,
        getVouch,
        getVouchByIndex,
        getBorrowed,
        borrowWithFee,
        updateTrust,
        cancelVouch,
        borrow,
        repay,
        repayFull,
        stake,
        withOverdueblocks
    };
};
