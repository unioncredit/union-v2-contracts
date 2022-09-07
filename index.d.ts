declare module "mocha" {
    interface SuiteFunction {
        fork: any;
    }
}

declare global {
    export namespace Chai {
        interface Assertion {
            revertedWithSig(sig: string): Promise<void>;
        }
    }
}

export {};
