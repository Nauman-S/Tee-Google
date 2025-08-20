// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IDKIMRegistry {
    // Events
    event KeyRegistered(
        bytes publicKey, 
        string indexed domain, 
        string indexed selector
    );
    
    event DKIMKeyRevoked(
        string indexed domain, 
        string indexed selector
    );

    function storeDKIMKeysFromAttestation(
        bytes calldata attestation
    ) external;
    
    function getDKIMKey(
        string calldata domain,
        string calldata selector
    ) external view returns (
        bytes memory publicKey,
        bool isValid
    );
    
    // Dev debugging only
    function getAllDKIMKeys() external view returns (
        string[] memory domains,
        string[] memory selectors, 
        bytes[] memory publicKeys
    );
}