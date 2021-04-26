certoraRun  spec/harness/SymbolicStrategy.sol:SymbolicStrategy spec/harness/DummyERC20A.sol:DummyERC20A spec/harness/Receiver.sol:Receiver --link SymbolicStrategy:token=DummyERC20A SymbolicStrategy:receiver=Receiver \
	--verify SymbolicStrategy:spec/strategy.spec \
	--settings -ciMode=true --path $PWD \
	--cloud --msg "strategy"