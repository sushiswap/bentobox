const { expect } = require("chai")
const { createFixture } = require("./utilities")

let cmd, fixture

describe("BentoHelper", function () {
    before(async function () {
        fixture = await createFixture(deployments, this, async (cmd) => {
            await cmd.deploy("helper", "BentoHelper")
        })
    })

    beforeEach(async function () {
        cmd = await fixture()
    })
})
