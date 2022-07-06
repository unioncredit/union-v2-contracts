import {BigNumberish, Signer} from "ethers";
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
    getStakedAmounts: (...args: Signer[]) => Promise<BigNumberish[]>;
    calculateRewards: (...args: Signer[]) => Promise<BigNumberish[]>;
    getRewardsMultipliers: (...args: Signer[]) => Promise<BigNumberish[]>;
    updateTrust: (staker: Signer, borrower: Signer, amount: BigNumberish) => Promise<void>;
    borrow: (borrower: Signer, amount: BigNumberish) => Promise<void>;
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

    /** ---------------------------------------------------------
     * Payable Functions
     * ------------------------------------------------------- */

    const updateTrust = async (staker: Signer, borrower: Signer, amount: BigNumberish) => {
        const borrowerAddress = await borrower.getAddress();
        await contracts.userManager.connect(staker).updateTrust(borrowerAddress, amount);
    };

    const borrow = async (borrower: Signer, amount: BigNumberish) => {
        await contracts.uToken.connect(borrower).borrow(amount);
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

    return {getStakedAmounts, calculateRewards, withOverdueblocks, getRewardsMultipliers, updateTrust, borrow, stake};
};
