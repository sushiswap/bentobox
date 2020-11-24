const truffleAssert = require('./helpers/truffle-assertions');
const timeWarp = require("./helpers/timeWarp");
const permit = require("./helpers/permit");
const {e18} = require("./helpers/utils");
const BentoBox = artifacts.require("BentoBox");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const Pair = artifacts.require("LendingPair");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");
const ethereumjsUtil = require('ethereumjs-util');
const {getDataParameter} = require("./helpers/getInitData");
const {ecsign} = ethereumjsUtil;

function netBorrowFee(amount) {
  const withDecimals = new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
  return withDecimals.mul(new web3.utils.BN("2000")).div(new web3.utils.BN("2001"));
}

async function logStatus(bentoBox, pair, a, b, alice, bob) {
    console.log('BentoBox contract');
    console.log('A', (await a.balanceOf(bentoBox.address)).toString(), 'of', (await a.totalSupply()).toString());
    console.log('B', (await b.balanceOf(bentoBox.address)).toString(), 'of', (await b.totalSupply()).toString());
    console.log('P', (await pair.balanceOf(bentoBox.address)).toString(), 'of', (await pair.totalSupply()).toString());
    console.log();
    console.log('Pair contract');
    console.log('A in bentoBox', (await bentoBox.shareOf(a.address, pair.address)).toString(), 'of', (await bentoBox.totalShare(a.address)).toString(), 'total balance is', (await bentoBox.totalBalance(a.address)).toString());
    console.log('B in bentoBox', (await bentoBox.shareOf(b.address, pair.address)).toString(), 'of', (await bentoBox.totalShare(b.address)).toString(), 'total balance is', (await bentoBox.totalBalance(b.address)).toString());
    console.log();
    console.log('Alice');
    console.log('A', (await a.balanceOf(alice)).toString());
    console.log('B', (await b.balanceOf(alice)).toString());
    console.log('P', (await pair.balanceOf(alice)).toString());
    console.log();
    console.log('Bob');
    console.log('A', (await a.balanceOf(bob)).toString());
    console.log('B', (await b.balanceOf(bob)).toString());
    console.log('P', (await pair.balanceOf(bob)).toString());
    console.log();
}

contract('LendingPair', (accounts) => {
  let a;
  let b;
  let pair_address;
  let pair;
  let bentoBox;
  let bentoFactory;
  let swapper;
  const alice = accounts[1];
  const bob = accounts[2];
  const dummy = accounts[4];
  const private_key = "0x043a569345b08ead19d1d4ba3462b30632feba623a2a85a3b000eb97f709f09f";
  const public_key = "0xb65CC031e6D92333BfDC441F5E36c4118Fe6838E";

  before(async () => {
    bentoBox = await BentoBox.deployed();
    pairMaster = await Pair.deployed();

    a = await TokenA.new({ from: accounts[0] });
    b = await TokenB.new({ from: accounts[0] });

    let factory = await SushiSwapFactory.new(accounts[0], { from: accounts[0] });
    swapper = await SushiSwapDelegateSwapper.new(factory.address, { from: accounts[0] });
    await pairMaster.setSwapper(swapper.address, true);

    let tx = await factory.createPair(a.address, b.address);
    let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
    await a.transfer(sushiswappair.address, e18("5000"));
    await b.transfer(sushiswappair.address, e18("5000"));
    await sushiswappair.mint(accounts[0]);

    await a.transfer(alice, e18(1000));
    await b.transfer(bob, e18(1000));

    oracle = await TestOracle.new({ from: accounts[0] });
    let oracleData = getDataParameter(TestOracle._json.abi, ["1000000000000000000"]);

    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: alice });
    await bentoBox.setMasterContractApproval(pairMaster.address, true, { from: bob });
    let initData = getInitData(Pair._json.abi, [a.address, b.address, oracle.address, oracleData]);
    tx = await bentoBox.deploy(pairMaster.address, initData);
    pair_address = tx.logs[0].args[2];
    pair = await Pair.at(pair_address);

    await pair.updateExchangeRate();
  });


  it('should not allow any remove without assets', async () => {
    await truffleAssert.reverts(pair.removeCollateral(e18(1), bob), 'BoringMath: Underflow');
    await truffleAssert.reverts(pair.removeAsset(e18(1), bob), 'BoringMath: Underflow');
  });

  it('should not allow borrowing without any assets', async () => {
    await truffleAssert.reverts(pair.borrow(e18(1), bob), 'BentoBox: not enough liquidity');
  });

  it('should take a deposit of assets', async () => {
    await b.approve(bentoBox.address, e18(300), { from: bob });
    await pair.addAsset(e18(300), { from: bob });
  });

  it('should give back correct DOMAIN_SEPARATOR', async () => {
    const domain_separator = permit.getDomainSeparator(pair_address);
    assert.equal(await pair.DOMAIN_SEPARATOR(), domain_separator);
  });

  it('should execute a permit', async () => {
    let nonce = await pair.nonces(public_key);
    nonce = nonce.toNumber();
    let block = await web3.eth.getBlock("latest");
    const deadline = Number(block.timestamp)+10000;
    const digest = await permit.getApprovalDigest(
        pair_address,
        {owner: public_key, spender: alice, value: 10},
        nonce,
        deadline
      );
    const {v, r, s} = ecsign(
        Buffer.from(digest.slice(2), 'hex'),
        Buffer.from(private_key.replace('0x', ''), 'hex')
    );
    await pair.permit(public_key, alice, 10, deadline, v, r, s);
  });

  it('permit should revert on old deadline', async () => {
    let nonce = await pair.nonces(public_key);
    nonce = nonce.toNumber();
    const deadline = 0;
    const digest = await permit.getApprovalDigest(
        pair_address,
        {owner: public_key, spender: alice, value: 10},
        nonce,
        deadline
      );
    const {v, r, s} = ecsign(
        Buffer.from(digest.slice(2), 'hex'),
        Buffer.from(private_key.replace('0x', ''), 'hex')
    );
    await truffleAssert.reverts(pair.permit(public_key, alice, 10, deadline, v, r, s), 'BentoBox: Expired');
  });

  it('permit should revert on incorrect signer', async () => {
    let nonce = await pair.nonces(public_key);
    nonce = nonce.toNumber();
    let block = await web3.eth.getBlock("latest");
    const deadline = Number(block.timestamp)+10000;
    const digest = await permit.getApprovalDigest(
        pair_address,
        {owner: public_key, spender: alice, value: 10},
        nonce,
        deadline
      );
    const {v, r, s} = ecsign(
        Buffer.from(digest.slice(2), 'hex'),
        Buffer.from(private_key.replace('0x', ''), 'hex')
    );
    await truffleAssert.reverts(pair.permit(bob, alice, 10, deadline, v, r, s), 'BentoBox: Invalid Signature');
  });

  it('should have correct balances after supply of assets', async () => {
    assert.equal((await pair.totalSupply()).toString(), e18(300).toString());
    assert.equal((await pair.balanceOf(bob)).toString(), e18(300).toString());
  })

  it('should not allow borrowing without any collateral', async () => {
    await truffleAssert.reverts(pair.borrow(e18(1), alice, { from: alice }), 'BentoBox: user insolvent');
  });

  it('should take a deposit of collateral', async () => {
    await a.approve(bentoBox.address, e18(100), { from: alice });
    await pair.addCollateral(e18(100), { from: alice });
  });

  it('should have correct balances after supply of collateral', async () => {
    assert.equal((await pair.totalCollateral()).toString(), e18(100).toString());
    assert.equal((await pair.userCollateral(alice)).toString(), e18(100).toString());
  })

  it('should allow borrowing with collateral up to 75%', async () => {
    await pair.borrow(netBorrowFee(75), alice, { from: alice });
  });

  // it('should not allow any more borrowing', async () => {
  //   await truffleAssert.reverts(pair.borrow(100, alice, { from: alice }), 'BentoBox: user insolvent');
  // });

  // it('should report insolvency due to interest', async () => {
  //   await pair.accrue();
  //   assert.equal(await pair.isSolvent(alice, false), false);
  // })

  it('should not report open insolvency due to interest', async () => {
    await pair.accrue();
    assert.equal(await pair.isSolvent(alice, true), true);
  })

  it('should not allow open liquidate yet', async () => {
    await b.approve(bentoBox.address, e18(25), { from: bob });
    await truffleAssert.reverts(pair.liquidate([alice], [e18(20)], bob, "0x0000000000000000000000000000000000000000", true, { from: bob }), 'BentoBox: all users are solvent');
  });

  // it('should allow closed liquidate', async () => {
  //   let tx = await pair.liquidate([alice], [e18(10)], bob, swapper.address, false, { from: bob });
  // });

  it('should report open insolvency after oracle rate is updated', async () => {
    await oracle.set("1100000000000000000", pair.address);
    await pair.updateExchangeRate();
    assert.equal(await pair.isSolvent(alice, true), false);
  })

  it('should allow open liquidate', async () => {
    await b.approve(bentoBox.address, e18(25), { from: bob });
    await pair.liquidate([alice], [e18(10)], bob, "0x0000000000000000000000000000000000000000", true, { from: bob });
  });

  it('should allow repay', async () => {
    await b.approve(bentoBox.address, e18(100), { from: alice });
    await pair.repay(e18(50), { from: alice });
  });

  it('should allow full repay with funds', async () => {
    let borrowShareLeft = await pair.userBorrowShare(alice);
    await pair.repay(borrowShareLeft, { from: alice });
  });

  it('should allow partial withdrawal of collateral', async () => {
    await pair.removeCollateral(e18(60), alice, { from: alice });
  });

  it('should not allow withdrawal of more than collateral', async () => {
    await truffleAssert.reverts(pair.removeCollateral(e18(100), alice, { from: alice }), "BoringMath: Underflow");
  });

  it('should allow full withdrawal of collateral', async () => {
    let shareALeft = await pair.userCollateral(alice);
    await pair.removeCollateral(shareALeft, alice, { from: alice });
  });

  it('should update the interest rate', async () => {
    for (let i = 0; i < 20; i++) {
      await timeWarp.advanceBlock()
    }
    await pair.updateInterestRate({ from: alice });
  });
});
