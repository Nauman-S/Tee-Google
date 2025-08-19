// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IDKIMRegistry} from "./IDKIMRegistry.sol";

contract DKIMRegistry is IDKIMRegistry {



    struct DKIMKey {
        bytes publicKey;
    }

    mapping(string => mapping(string => DKIMKey)) private keys;

    // Dev debugging only
    string[] private allDomains;
    string[] private allSelectors;


    function storeDKIMKeysFromAttestation(
        bytes calldata attestationTbs
    ) external override {
        (string memory domain, string memory selector, bytes memory publicKey) = 
            _parseAttestation(attestationTbs);
        
        if (keys[domain][selector].publicKey.length > 0) {
            return;
        }

        keys[domain][selector] = DKIMKey({
            publicKey: publicKey
        });

        allDomains.push(domain);
        allSelectors.push(selector);

        emit KeyRegistered(publicKey, domain, selector);
    }



    function getDKIMKey(
        string calldata domain,
        string calldata selector
    ) external view override returns (
        bytes memory publicKey,
        bool isValid
    ) {
        DKIMKey storage key = keys[domain][selector];
        
        if (key.publicKey.length == 0) {
            return ("", false);
        }
        
        return (key.publicKey, true); // Always true for now
    }

    // Dev debugging only
    function getAllDKIMKeys() external view override returns (
        string[] memory domains,
        string[] memory selectors,
        bytes[] memory publicKeys
    ) {
        uint256 length = allDomains.length;
        domains = new string[](length);
        selectors = new string[](length);
        publicKeys = new bytes[](length);
        
        for (uint256 i = 0; i < length; i++) {
            domains[i] = allDomains[i];
            selectors[i] = allSelectors[i];
            publicKeys[i] = keys[allDomains[i]][allSelectors[i]].publicKey;
        }
        
        return (domains, selectors, publicKeys);
    }

    function _parseAttestation(bytes calldata attestationTbs) private pure returns (
        string memory domain,
        string memory selector,
        bytes memory publicKey
    ) {
        // Stub implementation - replace with actual parsing
        domain = "example.com";
        selector = "default";
        publicKey = hex"1234567890abcdef";
    }

}