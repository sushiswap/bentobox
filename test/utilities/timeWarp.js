
advanceTimeAndBlock = async (time, ethers) => {
    await advanceTime(time,ethers);
    await advanceBlock(ethers);
    let blockNumber = await ethers.provider.getBlockNumber();
    return Promise.resolve(blockNumber);
}

advanceTime = (time, ethers) => {
    return new Promise((resolve, reject) => {
        ethers.provider.send({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time],
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err); }
            return resolve(result);
        });
    });
}

advanceBlock = (ethers) => {
    return new Promise((resolve, reject) => {
        ethers.provider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err); }

            return resolve()
        });
    });
}

module.exports = {
    advanceTime,
    advanceBlock,
    advanceTimeAndBlock
}