pragma solidity ^0.6.12;

import "./libraries/Ownable.sol";
import './interfaces/IBentoFactory.sol';
import './interfaces/IPair.sol';
import './interfaces/IERC20.sol';

contract BentoFactory is IBentoFactory {
    address public vault;
    IPair public masterContract;
    mapping(address => mapping(address => address)) public getPair;

    event PairCreated(IERC20 indexed collateral, IERC20 indexed asset, IPair pair, address oracle);

    constructor(address vault_, IPair master_contract) public {
        require(vault_ != address(0), 'BentoFactory: ZERO_ADDRESS');
        vault = vault_;
        require(address(master_contract) != address(0), 'BentoFactory: ZERO_ADDRESS');
        masterContract = master_contract;
    }

    function createPair(IERC20 collateral, IERC20 asset, IOracle oracle_address, bytes calldata oracleData) external override {
        require(collateral != asset, 'BentoFactory: IDENTICAL_ADDRESSES');
        require(address(collateral) != address(0), 'BentoFactory: ZERO_ADDRESS');
        require(address(asset) != address(0), 'BentoFactory: ZERO_ADDRESS');
        require(getPair[address(collateral)][address(asset)] == address(0), 'BentoFactory: PAIR_EXISTS'); // single check is sufficient
        bytes20 targetBytes = bytes20(address(masterContract)); // Takes the first 20 bytes of the masterContract's address
        address clone_address; // Address where the clone contract will reside.

        // Creates clone, more info here: https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            clone_address := create(0, clone, 0x37)
        }

        (bool success,) = clone_address.call(masterContract.getInitData(collateral, asset, oracle_address, oracleData));
        require(success, 'BentoFactory: contract init failed.');
        IPair(clone_address).setVault(vault);

        getPair[address(collateral)][address(asset)] = clone_address;
        emit PairCreated(collateral, asset, IPair(clone_address), address(oracle_address));
    }

    function setMasterContract(IPair master_contract) external override {
        require(msg.sender == Ownable(vault).owner(), 'BentoFactory: FORBIDDEN');
        require(address(master_contract) != address(0), 'BentoFactory: ZERO_ADDRESS');
        masterContract = master_contract;
    }

}