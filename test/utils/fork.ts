export const isForked = () => {
    return process.env.FORK_NODE_URL && process.env.FORK_BLOCK;
};
