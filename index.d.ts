declare module "mocha" {
    interface SuiteFunction {
        fork: SuiteFunction 
    }
}

export {};