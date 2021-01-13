const { ADDRESS_ZERO, setMasterContractApproval, prepare } = require("./utilities")
const { expect } = require("chai")

describe("StrategyManager", function () {
  before(async function () {
    await prepare(this, ["StrategyManagerMock"])
  })

  beforeEach(async function () {

  })
})
