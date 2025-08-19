// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../contracts/CertManagerReduced.sol";
import "../../contracts/CertStorage.sol";
import "../../contracts/CertParser.sol";
import "../../contracts/ICertManager.sol";
import "../../contracts/DKIMOracle.sol";
import "../../contracts/DKIMRegistry.sol";
import "../../contracts/Counter.sol";



contract DeployDKIMOracleReduced is Script {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    
    function run() public {
        // Log deployer info for verification
        console2.log("=== DEPLOYER INFO ===");
        console2.log("Deployer address:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        // 1. Deploy to local anvil
        vm.createSelectFork("http://127.0.0.1:8545");
        console2.log("block.chainID", block.chainid);
        require(block.chainid == 31337, "must be local anvil chainId");


        vm.startBroadcast(deployer);

        // Deploy CertStorage first
        CertStorage certStorage = new CertStorage();
        address certStorageAddress = address(certStorage);
        console2.log("CertStorage deployed: %s", certStorageAddress);

        // Deploy CertParser
        CertParser certParser = new CertParser();
        address certParserAddress = address(certParser);
        console2.log("CertParser deployed: %s", certParserAddress);

        // Deploy CertManagerReduced (requires CertStorage and CertParser)
        CertManager certManager = new CertManager(certStorage, certParser);
        address certManagerAddress = address(certManager);
        console2.log("CertManagerReduced deployed: %s", certManagerAddress);

        // Deploy DKIM Oracle (requires CertManager address)
        DKIMOracle oracle = new DKIMOracle(ICertManager(certManagerAddress));
        address oracleAddress = address(oracle);
        console2.log("DKIMOracle deployed: %s", oracleAddress);

        // Deploy DKIM Registry 
        DKIMRegistry registry = new DKIMRegistry();
        address registryAddress = address(registry);
        console2.log("DKIMRegistry deployed: %s", registryAddress);
        
        vm.stopBroadcast();

        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: Chain ID %s", block.chainid);
        console2.log("Deployer: %s", deployer);
        console2.log("CertStorage: %s", certStorageAddress);
        console2.log("CertParser: %s", certParserAddress);
        console2.log("CertManagerReduced: %s", certManagerAddress);
        console2.log("DKIMOracle: %s", oracleAddress);
        console2.log("DKIMRegistry: %s", registryAddress);
    }
}