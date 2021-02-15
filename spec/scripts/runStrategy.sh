certoraRun.py  spec/harness/SymbolicStrategy.sol:SymbolicStrategy spec/harness/DummyERC20A.sol:DummyERC20A 	spec/harness/Owner.sol:Owner --link SymbolicStrategy:token=DummyERC20A SymbolicStrategy:owner=Owner --solc solc6.12 \
	--verify SymbolicStrategy:spec/strategy.spec \
	--staging --msg "strategy"