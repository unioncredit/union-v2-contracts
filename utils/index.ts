import {BigNumber} from "ethers";
import {parseUnits} from "ethers/lib/utils";

export const parseUSDC = (value: string): BigNumber => {
    return parseUnits(value, 6);
};
