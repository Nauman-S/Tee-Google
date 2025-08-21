// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../contracts/CertManager.sol";
import "../../contracts/ICertManager.sol";
import "../../contracts/DKIMOracle.sol";
import "../../contracts/DKIMRegistry.sol";
import "../../contracts/Counter.sol";



contract DeployDKIMOracle is Script {
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

        // Deploy Counter contract  
        Counter counter = new Counter();
        address counterAddress = address(counter);
        console2.log("Counter deployed: %s", counterAddress);

        // Deploy CertManager first (DKIMOracle depends on it)
        CertManager certManager = new CertManager(); //forge build --sizes , currently contract is too large to deploy
        address certManagerAddress = address(certManager);
        console2.log("CertManager deployed: %s", certManagerAddress);

        // Deploy DKIM Oracle (requires CertManager address)
        DKIMOracle oracle = new DKIMOracle(ICertManager(certManagerAddress));
        address oracleAddress = address(oracle);
        console2.log("DKIMOracle deployed: %s", oracleAddress);

        // Deploy DKIM Registry (requires DKIMOracle instance)
        DKIMRegistry registry = new DKIMRegistry(oracle);
        address registryAddress = address(registry);
        console2.log("DKIMRegistry deployed: %s", registryAddress);
        
        vm.stopBroadcast();

        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: Chain ID %s", block.chainid);
        console2.log("Deployer: %s", deployer);
        console2.log("Counter: %s", counterAddress);
        console2.log("CertManager: %s", certManagerAddress);
        console2.log("DKIMOracle: %s", oracleAddress);
        console2.log("DKIMRegistry: %s", registryAddress);
    }
}