certoraRun spec/harness/CompoundStrategyHarness.sol spec/harness/DummyERC20A.sol spec/harness/DummyERC20B.sol spec/harness/Owner.sol spec/harness/Receiver.sol spec/compound/CErc20.sol \
--link CompoundStrategyHarness:token=DummyERC20A CompoundStrategyHarness:owner=Owner CompoundStrategyHarness:bentobox=Receiver CompoundStrategyHarness:cToken=CErc20 CompoundStrategyHarness:compToken=DummyERC20B CErc20:underlying=DummyERC20A \
--verify CompoundStrategyHarness:spec/compoundStrategy.spec \
--settings -assumeUnwindCond \
--solc_map CompoundStrategyHarness=solc,CErc20=solc5.17,DummyERC20A=solc,Owner=solc,Receiver=solc,DummyERC20B=solc --path $PWD \
--msg "CompoundStrategy spec" 