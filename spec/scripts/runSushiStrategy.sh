certoraRun spec/harness/SushiStrategyHarness.sol \
spec/harness/DummyERC20A.sol \
spec/harness/Receiver.sol \
--link SushiStrategyHarness:sushi=DummyERC20A SushiStrategyHarness:owner=Receiver \
--verify SushiStrategyHarness:spec/strategy.spec \
--cloud \
--settings -ciMode=true \
--msg "sushiStrategy"