certoraRun spec/harness/SushiStrategyHarness.sol \
spec/harness/DummyERC20A.sol \
spec/harness/Owner.sol \
--link SushiStrategyHarness:sushi=DummyERC20A SushiStrategyHarness:owner=Owner \
--verify SushiStrategyHarness:spec/strategy.spec \
--cloud \
--msg "sushiStrategy"