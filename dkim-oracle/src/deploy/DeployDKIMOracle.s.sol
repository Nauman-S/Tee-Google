// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";

// Import your oracle contracts (create these files)
// import "../../contracts/DKIMOracle.sol";
// import "../../contracts/EmailRecovery.sol";
// import "../../contracts/PublicKeyRegistry.sol";

import "../../contracts/Counter.sol";



contract DKIMOracle is Test {
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

        // The DKIM contracts will be deployed later when ready
        // address publicKeyRegistry = address(new PublicKeyRegistry());
        // address dkimOracle = address(new DKIMOracle(publicKeyRegistry));
        // address emailRecovery = address(new EmailRecovery(dkimOracle));
        
        vm.stopBroadcast();

        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: Chain ID %s", block.chainid);
        console2.log("Deployer: %s", deployer);
        console2.log("Counter: %s", counterAddress);
    }
}