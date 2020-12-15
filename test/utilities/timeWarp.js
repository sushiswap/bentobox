
advanceTimeAndBlock = async (time, ethers) => {
    await advanceTime(time,ethers);
    await advanceBlock(ethers);
    let blockNumber = await ethers.provider.getBlockNumber();
    return Promise.resolve(blockNumber);
}

advanceTime = (time, ethers) => {
    return ethers.provider.send("evm_increaseTime", [time])
}

advanceBlock = (ethers) => {
    return ethers.provider.send("evm_mine")
}

module.exports = {
    advanceTime,
    advanceBlock,
    advanceTimeAndBlock
}