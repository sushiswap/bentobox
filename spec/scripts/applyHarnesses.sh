############################################################
#                         BentoBox                         #
############################################################
# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/BentoBox.sol

# Virtualize functions
perl -0777 -i -pe 's/\) public allowed\(from\)/\) virtual public allowed\(from\)/g' contracts/BentoBox.sol
perl -0777 -i -pe 's/\) public \{/\) virtual public \{ /g' contracts/BentoBox.sol

# De-virtualize constructor
perl -0777 -i -pe 's/constructor\(IERC20 wethToken_\) virtual public/constructor\(IERC20 wethToken_\) public/g' contracts/BentoBox.sol

# Virtualize more functions
perl -0777 -i -pe 's/\) external payable returns \(/\) external virtual payable returns \(/g' node_modules/@boringcrypto/boring-solidity/contracts/BoringBatchable.sol
perl -0777 -i -pe 's/\) public payable /\) public virtual payable /g' node_modules/@boringcrypto/boring-solidity/contracts/BoringFactory.sol

# Add transfer function declaration
perl -0777 -i -pe 's/\}/function transfer\(address to, uint256 amount\) external;\n function transferFrom\(address from, address to, uint256 amount\) external;\n\}/g' node_modules/@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol

############################################################
#                     Compound Strategy                    #
############################################################
# SafeTransfer simplification
perl -0777 -i -pe 's/safeT/t/g' contracts/strategies/CompoundStrategy.sol

# Removing try catch
perl -0777 -i -pe 's/try cToken.redeem\(cToken.balanceOf\(address\(this\)\)\) \{\} catch \{\}/cToken.redeem\(cToken.balanceOf\(address\(this\)\)\);/g' contracts/strategies/CompoundStrategy.sol
perl -0777 -i -pe 's/try cToken.redeemUnderlying\(available\) \{\} catch \{\}/cToken.redeemUnderlying\(available\);/g' contracts/strategies/CompoundStrategy.sol

# Adding fix for to.call
perl -0777 -i -pe "s/import \"..\/interfaces\/IStrategy.sol\";/import \"..\/interfaces\/IStrategy.sol\";\nimport \"spec\/harness\/Nothing.sol\";/g" contracts/strategies/CompoundStrategy.sol
perl -0777 -i -pe "s/to.call\{value: value\}\(data\)/Nothing\(to\).nop\{value: value\}\(data\)/g" contracts/strategies/CompoundStrategy.sol