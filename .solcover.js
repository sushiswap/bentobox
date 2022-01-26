module.exports = {
  skipFiles: [
    'flat',
    'libraries',
    'mocks',
    'interfaces',
    'oracles/ChainlinkOracle.sol',
    'oracles/CompoundOracle.sol',
    'samples/salary.sol',
    'BentoHelper.sol',
  ],
  mocha: {
    fgrep: '[skip-on-coverage]',
    invert: true,
  },
}
