// rollup.config.js
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import json from "@rollup/plugin-json";

export default {
    input: "scripts/updateOverdueInfo.js",
    output: {
        file: "dist/index.js",
        format: "cjs"
    },
    plugins: [commonjs(), resolve({resolveOnly: ["graphql-request"]}), json()]
};
