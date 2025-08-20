// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IDKIMRegistry} from "./IDKIMRegistry.sol";
import {DKIMOracle} from "./DKIMOracle.sol";
import {CborElement, LibCborElement} from "./CborDecode.sol";
import {LibBytes} from "./LibBytes.sol";

contract DKIMRegistry is IDKIMRegistry {
    using LibBytes for bytes;
    using LibCborElement for CborElement;
    
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

    function _extractBytes(bytes calldata attestation, CborElement element) private pure returns (bytes memory) {
        return attestation.slice(element.start(), element.length());
    }
    
    function _parseAndStoreDKIMKeys(bytes memory userDataBytes) private {
        //{"provider":"google","jwks_keys":{...},"dkim_keys":{"domain":{"selector":"base64key"}}}
        string memory userData = string(userDataBytes);
        
        // Find "dkim_keys" section
        uint256 dkimKeysStart = _findSubstring(userData, '"dkim_keys":');
        if (dkimKeysStart == type(uint256).max) {
            return; // No DKIM keys found
        }
        
        // Move past "dkim_keys":
        dkimKeysStart += 12; // Length of '"dkim_keys":'
        
        // Skip whitespace to find the opening brace  
        bytes memory userDataBytesRef = bytes(userData);
        dkimKeysStart = _skipWhitespace(userDataBytesRef, dkimKeysStart);
        
        // Check for opening brace
        if (dkimKeysStart >= userDataBytesRef.length || userDataBytesRef[dkimKeysStart] != '{') {
            return;
        }
        
        dkimKeysStart += 1; // Move past '{'
        
        // Parse each domain
        uint256 pos = dkimKeysStart;
        
        while (pos < userDataBytesRef.length) {
            // Skip whitespace
            pos = _skipWhitespace(userDataBytesRef, pos);
            
            if (pos >= userDataBytesRef.length || userDataBytesRef[pos] == '}') {
                break; // End of dkim_keys object
            }
            
            // Parse domain name (quoted string)
            if (userDataBytesRef[pos] == '"') {
                pos += 1; // Skip opening quote
                uint256 domainStart = pos;
                pos = _findChar(userData, '"', pos); // Find closing quote
                if (pos == type(uint256).max) {
                    break;
                }
                
                string memory domain = _substring(userData, domainStart, pos);
                pos += 1; // Skip closing quote
                
                // Skip colon and whitespace
                pos = _skipWhitespace(userDataBytesRef, pos);
                if (pos >= userDataBytesRef.length || userDataBytesRef[pos] != ':') break;
                pos += 1; // Skip ':'
                pos = _skipWhitespace(userDataBytesRef, pos);
                
                // Parse selectors object
                if (pos < userDataBytesRef.length && userDataBytesRef[pos] == '{') {
                    pos += 1; // Skip '{'
                    pos = _parseSelectorsForDomain(userData, userDataBytesRef, pos, domain);
                }
            }
            
            // Skip to next domain (look for comma or end)
            pos = _skipWhitespace(userDataBytesRef, pos);
            if (pos < userDataBytesRef.length && userDataBytesRef[pos] == ',') {
                pos += 1; // Skip comma
            }
        }
    }
    
    function _parseSelectorsForDomain(string memory userData, bytes memory userDataBytes, uint256 startPos, string memory domain) private returns (uint256) {
        uint256 pos = startPos;
        
        while (pos < userDataBytes.length) {
            // Skip whitespace
            pos = _skipWhitespace(userDataBytes, pos);
            if (pos >= userDataBytes.length || userDataBytes[pos] == '}') {
                return pos + 1; // End of selectors object
            }
            
            // Parse selector name (quoted string)
            if (userDataBytes[pos] == '"') {
                pos += 1; // Skip opening quote
                uint256 selectorStart = pos;
                pos = _findChar(userData, '"', pos); // Find closing quote
                if (pos == type(uint256).max) break;
                
                string memory selector = _substring(userData, selectorStart, pos);
                pos += 1; // Skip closing quote
                
                // Skip colon and whitespace
                pos = _skipWhitespace(userDataBytes, pos);
                if (pos >= userDataBytes.length || userDataBytes[pos] != ':') break;
                pos += 1; // Skip ':'
                pos = _skipWhitespace(userDataBytes, pos);
                
                // Parse public key (quoted string)
                if (pos < userDataBytes.length && userDataBytes[pos] == '"') {
                    pos += 1; // Skip opening quote
                    uint256 keyStart = pos;
                    pos = _findChar(userData, '"', pos); // Find closing quote
                    if (pos == type(uint256).max) break;
                    
                    string memory publicKeyStr = _substring(userData, keyStart, pos);
                    bytes memory publicKey = bytes(publicKeyStr);
                    pos += 1; // Skip closing quote
                    
                    // Store the key if not already exists
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
            
            // Skip to next selector (look for comma or end)
            pos = _skipWhitespace(userDataBytes, pos);
            if (pos < userDataBytes.length && userDataBytes[pos] == ',') {
                pos += 1; // Skip comma
            }
        }
        
        return pos;
    }
    
    // Helper functions for string parsing
    function _findSubstring(string memory str, string memory substr) private pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length > strBytes.length) {
            return type(uint256).max;
        }
        
        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return i;
            }
        }
        
        return type(uint256).max;
    }
    
    function _findChar(string memory str, bytes1 char, uint256 startPos) private pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        for (uint256 i = startPos; i < strBytes.length; i++) {
            if (strBytes[i] == char) {
                return i;
            }
        }
        return type(uint256).max;
    }
    
    function _skipWhitespace(bytes memory data, uint256 pos) private pure returns (uint256) {
        while (pos < data.length && (data[pos] == ' ' || data[pos] == '\t' || data[pos] == '\n' || data[pos] == '\r')) {
            pos++;
        }
        return pos;
    }
    
    function _substring(string memory str, uint256 start, uint256 end) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = strBytes[start + i];
        }
        return string(result);
    }

}