import {SuiteFunction} from "mocha";
import {fork} from "../utils";
import {isForked} from "../utils/fork";

const noop = () => {};

const originalDescribe = describe;

// Override the describe function to include custom before
// behaviour globally
const customDescribe = ((str: string, tests: () => void) => {
    originalDescribe(str, () => {
        before(async () => {
            // Reset the fork if we are in fork mode
            if (isForked()) await fork();
        });
        tests();
    });
}) as SuiteFunction;

// For test suites that we only want to run in forked mode
describe.fork = ((runnable: () => boolean, str: string, cb: () => void = noop) => {
    const name = `[FORK] ${str}`;

    if (isForked() && runnable()) {
        customDescribe(name, cb);
    } else {
        describe.skip(name, cb);
    }
}) as any;
