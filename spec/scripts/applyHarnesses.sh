# SafeTransfer simplification
sed -i 's/safeT/t/g' contracts/BentoBox.sol
sed -i 's/safeT/t/g' contracts/LendingPair.sol
# Virtualize functions
perl -0777 -i -pe 's/\) public allowed\(from\)/\) virtual public allowed\(from\)/g' contracts/BentoBox.sol
perl -0777 -i -pe 's/\) public \{/\) virtual public \{ /g' contracts/BentoBox.sol
perl -0777 -i -pe 's/\) external payable returns \(/\) external virtual payable returns \(/g' node_modules/@boringcrypto/boring-solidity/contracts/BoringBatchable.sol
perl -0777 -i -pe 's/\) public payable /\) public virtual payable /g' node_modules/@boringcrypto/boring-solidity/contracts/BoringFactory.sol
# Add transfer function declaration 
perl -0777 -i -pe 's/\}/function transfer\(address to, uint256 amount\) external;\n function transferFrom\(address from, address to, uint256 amount\) external;\n\}/g' node_modules/@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol
