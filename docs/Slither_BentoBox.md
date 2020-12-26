# BentoBox.sol Slither output and feedback

BentoBox.sol analyzed (6 contracts with 72 detectors), 25 result(s) found

## Functions that send Ether to arbitrary destinations
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations

        BentoBox.skimETHTo(address) (BentoBox.sol#154-157) sends eth to arbitrary user
        Dangerous calls:
        - IWETH(address(WETH)).deposit{value: address(this).balance}() (BentoBox.sol#155)

The skim function allows for ETH to be send to the BentoBox and skimmed into an account within the same transaction. This is correct and by design.

## Dangerous strict equalities
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities

        BentoBox._deposit(IERC20,address,address,uint256) (BentoBox.sol#174-190) uses a dangerous strict equality:
        - supply == 0 (BentoBox.sol#183)

This is correct as this should only happen the first time, when it's guaranteed 0.

## Uninitialized local variables
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-local-variables

        BentoBox._withdraw(IERC20,address,address,uint256).success_scope_0 (BentoBox.sol#201) is a local variable never initialized

Unclear why this was flagged, seems ok

## Calls inside a loop
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop

        BentoBox.batch(bytes[],bool) (BentoBox.sol#159-168) has external calls inside a loop: (success,result) = address(this).delegatecall(calls[i]) (BentoBox.sol#163)

This is correct, calls in a loop is exactly how batch should work. Reverting calls is dealt with properly.

## Pre-declaration usage of local variables
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#pre-declaration-usage-of-local-variables

        Variable 'BentoBox._withdraw(IERC20,address,address,uint256).success (BentoBox.sol#198)' in BentoBox._withdraw(IERC20,address,address,uint256) (BentoBox.sol#192-205) potentially used before declaration: (success,data) = address(token).call(abi.encodeWithSelector(0xa9059cbb,to,amount)) (BentoBox.sol#201)

Seems like an incorrect detection

## Reentrancy vulnerabilities
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-2

        Reentrancy in BentoBox.skimETHTo(address) (BentoBox.sol#154-157):
        External calls:
        - IWETH(address(WETH)).deposit{value: address(this).balance}() (BentoBox.sol#155)
        State variables written after the call(s):
        - amount = skimTo(WETH,to) (BentoBox.sol#156)
                - balanceOf[token][to] = balanceOf[token][to].add(amount) (BentoBox.sol#148)
        - amount = skimTo(WETH,to) (BentoBox.sol#156)
                - totalSupply[token] = totalSupply[token].add(amount) (BentoBox.sol#149)

## Reentrancy vulnerabilities
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3

        Reentrancy in BentoBox._deposit(IERC20,address,address,uint256) (BentoBox.sol#174-190):
        External calls:
        - IWETH(address(WETH)).deposit{value: amount}() (BentoBox.sol#181)
        - (success,data) = address(token).call(abi.encodeWithSelector(0x23b872dd,from,address(this),amount)) (BentoBox.sol#186)
        External calls sending eth:
        - IWETH(address(WETH)).deposit{value: amount}() (BentoBox.sol#181)
        Event emitted after the call(s):
        - LogDeposit(token,from,to,amount) (BentoBox.sol#189)

TODO

        Reentrancy in BentoBox._withdraw(IERC20,address,address,uint256) (BentoBox.sol#192-205):
        External calls:
        - IWETH(address(WETH)).withdraw(amount) (BentoBox.sol#197)
        - (success) = to.call{value: amount}(new bytes(0)) (BentoBox.sol#198)
        - (success,data) = address(token).call(abi.encodeWithSelector(0xa9059cbb,to,amount)) (BentoBox.sol#201)
        External calls sending eth:
        - (success) = to.call{value: amount}(new bytes(0)) (BentoBox.sol#198)
        Event emitted after the call(s):
        - LogWithdraw(token,from,to,amount) (BentoBox.sol#204)

TODO

        Reentrancy in BentoBox.deploy(address,bytes) (BentoBox.sol#52-69):
        External calls:
        - IMasterContract(cloneAddress).init(data) (BentoBox.sol#66)
        Event emitted after the call(s):
        - LogDeploy(masterContract,data,cloneAddress) (BentoBox.sol#68)

TODO

        Reentrancy in BentoBox.skimETHTo(address) (BentoBox.sol#154-157):
        External calls:
        - IWETH(address(WETH)).deposit{value: address(this).balance}() (BentoBox.sol#155)
        Event emitted after the call(s):
        - LogDeposit(token,address(this),to,amount) (BentoBox.sol#150)
                - amount = skimTo(WETH,to) (BentoBox.sol#156)

TODO

## Assembly usage
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#assembly-usage

        BentoBox.deploy(address,bytes) (BentoBox.sol#52-69) uses assembly
        - INLINE ASM (BentoBox.sol#57-63)
        BentoBox.DOMAIN_SEPARATOR() (BentoBox.sol#71-75) uses assembly
        - INLINE ASM (BentoBox.sol#73)

Assembly is used to create the minimal proxy contracts and for getting the chainId.

## Incorrect versions of Solidity
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity

        Pragma version0.6.12 (BentoBox.sol#20) necessitates a version too recent to be trusted. Consider deploying with 0.6.11
        solc-0.6.12 is not recommended for deployment

According to Peckshield auditor, using 0.6.12 is fine.

## Low level calls
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#low-level-calls

        Low level call in BentoBox.batch(bytes[],bool) (BentoBox.sol#159-168):
        - (success,result) = address(this).delegatecall(calls[i]) (BentoBox.sol#163)
        Low level call in BentoBox._deposit(IERC20,address,address,uint256) (BentoBox.sol#174-190):
        - (success,data) = address(token).call(abi.encodeWithSelector(0x23b872dd,from,address(this),amount)) (BentoBox.sol#186)
        Low level call in BentoBox._withdraw(IERC20,address,address,uint256) (BentoBox.sol#192-205):
        - (success) = to.call{value: amount}(new bytes(0)) (BentoBox.sol#198)
        - (success,data) = address(token).call(abi.encodeWithSelector(0xa9059cbb,to,amount)) (BentoBox.sol#201)

These low level calls are needed to handle reverts during the calls correctly.

## Conformance to Solidity naming conventions
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions

        Function BentoBox.DOMAIN_SEPARATOR() (BentoBox.sol#71-75) is not in mixedCase
        Variable BentoBox.WETH (BentoBox.sol#42) is not in mixedCase

Fixed

## Too many digits
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits

        BentoBox.deploy(address,bytes) (BentoBox.sol#52-69) uses literals with too many digits:
        - mstore(uint256,uint256)(clone_deploy_asm_0,0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000) (BentoBox.sol#59)
        BentoBox.deploy(address,bytes) (BentoBox.sol#52-69) uses literals with too many digits:
        - mstore(uint256,uint256)(clone_deploy_asm_0 + 0x28,0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000) (BentoBox.sol#61)

This is a standard implementation of EIP1167 Minimal Proxy Contract