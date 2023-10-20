declare module "mocha" {
    interface SuiteFunction {
        fork: any;
    }
}

declare global {
    export namespace Chai {
        interface Assertion {
            revertedWith(sig: string): Promise<void>;
        }
    }
}

export {};
