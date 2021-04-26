certoraRun spec/harness/BentoBoxHarness.sol spec/harness/DummyERC20A.sol spec/harness/DummyWeth.sol spec/harness/SymbolicStrategy.sol spec/harness/Owner.sol  spec/harness/Borrower.sol \
    --link  SymbolicStrategy:receiver=BentoBoxHarness Borrower:bentoBox=BentoBoxHarness \
	--settings -copyLoopUnroll=4,-b=4,-ignoreViewFunctions,-enableStorageAnalysis=true,-assumeUnwindCond,-ciMode=true \
	--verify BentoBoxHarness:spec/bentobox.spec \
	--cache bentoBox \
	--msg "BentoBox" 