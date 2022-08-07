import config from "./hardhat.config";

export default {
    ...config,
    paths: {...config.paths, tests: "./test/simulations"}
};
