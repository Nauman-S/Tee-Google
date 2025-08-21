// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IDKIMRegistry} from "./IDKIMRegistry.sol";
import {DKIMOracle} from "./DKIMOracle.sol";
import {CborDecode, CborElement, LibCborElement} from "./CborDecode.sol";
import {LibBytes} from "./LibBytes.sol";


/**
 * @title DKIMRegistry
 * @notice DKIM registry that expects only DKIM keys in attestation userData
 * @dev Expects userData to contain flattened structure: {"domain;selector":"base64key"}
 */
contract DKIMRegistry is IDKIMRegistry {
    using LibBytes for bytes;
    using LibCborElement for CborElement;
    using CborDecode for bytes;
    
    DKIMOracle public immutable dkimOracle;

    constructor(DKIMOracle _dkimOracle) {
        dkimOracle = _dkimOracle;
    }

    struct DKIMKey {
        bytes publicKey;
    }

    mapping(string => mapping(string => DKIMKey)) private keys;

    // Dev debugging only
    string[] private allDomains;
    string[] private allSelectors;

    function storeDKIMKeysFromAttestation(
        bytes calldata attestation
    ) external override {
        // Validate attestation and get structured data
        DKIMOracle.Ptrs memory ptrs = dkimOracle.decodeAndValidateAttestation(attestation);
        
        if (!ptrs.userData.isNull()) {
            bytes memory userDataBytes = _extractBytes(attestation, ptrs.userData);
            _parseAndStoreDKIMKeys(userDataBytes);
        }
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
        
        return (key.publicKey, true);
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

    function _extractBytes(bytes calldata attestation, CborElement element) private pure returns (bytes memory) {
        // WORKAROUND: The CBOR library has an 11-byte offset bug for userData
        // Adjust the start position to compensate
        uint256 adjustedStart = element.start();
        if (adjustedStart >= 11) {
            adjustedStart = adjustedStart - 11;
            
            // Verify the correction points to valid CBOR map
            if (adjustedStart < attestation.length && attestation[adjustedStart] == 0xa1) {
                // Use corrected boundaries
                uint256 correctedLength = element.length();
                if (adjustedStart + correctedLength > attestation.length) {
                    correctedLength = attestation.length - adjustedStart;
                }
                
                return attestation.slice(adjustedStart, correctedLength);
            }
        }
        
        // Fallback to original extraction
        return attestation.slice(element.start(), element.length());
    }
    
    /**
     * @notice Optimized CBOR parser for flattened DKIM structure
     * @dev Expected CBOR format: {"domain;selector": "base64key"}
     */
    function _parseAndStoreDKIMKeys(bytes memory userDataBytes) private {
        // Parse as simple CBOR map: {domain;selector: key}
        CborElement topLevel = userDataBytes.mapAt(0);
        uint256 numEntries = topLevel.value();
        uint256 end = userDataBytes.length;
        
        CborElement current = topLevel;
        
        // Iterate through all flattened entries
        for (uint256 i = 0; i < numEntries && current.end() < end; i++) {
            // Get the flattened key (domain;selector)
            current = userDataBytes.nextTextString(current);
            string memory flatKey = string(userDataBytes.slice(current));
            
            // Split on semicolon to get domain and selector
            (string memory domain, string memory selector) = _splitDomainSelector(flatKey);
            
            current = userDataBytes.nextTextString(current);
            bytes memory publicKey = userDataBytes.slice(current);
            
            if (bytes(domain).length > 0 && bytes(selector).length > 0) {
                if (keys[domain][selector].publicKey.length == 0) {
                    keys[domain][selector] = DKIMKey({
                        publicKey: publicKey
                    });
                    
                    allDomains.push(domain);
                    allSelectors.push(selector);
                    
                    emit KeyRegistered(publicKey, domain, selector);
                }
            }
        }
    }
    
    function _splitDomainSelector(string memory flatKey) private pure returns (string memory domain, string memory selector) {
        bytes memory flatKeyBytes = bytes(flatKey);
        uint256 semicolonPos = 0;
        
        for (uint256 i = 0; i < flatKeyBytes.length; i++) {
            if (flatKeyBytes[i] == 0x3b) {
                semicolonPos = i;
                break;
            }
        }
        
        if (semicolonPos > 0 && semicolonPos < flatKeyBytes.length - 1) {
            // domain
            bytes memory domainBytes = new bytes(semicolonPos);
            for (uint256 i = 0; i < semicolonPos; i++) {
                domainBytes[i] = flatKeyBytes[i];
            }
            domain = string(domainBytes);
            
            //selector
            uint256 selectorLength = flatKeyBytes.length - semicolonPos - 1;
            bytes memory selectorBytes = new bytes(selectorLength);
            for (uint256 i = 0; i < selectorLength; i++) {
                selectorBytes[i] = flatKeyBytes[semicolonPos + 1 + i];
            }
            selector = string(selectorBytes);
        }
    }
}
