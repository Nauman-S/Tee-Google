// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ICertManager} from "./ICertManager.sol";

contract CertStorage {
    event CertVerified(bytes32 indexed certHash);
    
    // certHash -> VerifiedCert encoded as bytes
    mapping(bytes32 => bytes) public verified;
    
    function saveVerified(bytes32 certHash, ICertManager.VerifiedCert memory cert) external {
        verified[certHash] = abi.encode(cert);
        emit CertVerified(certHash);
    }
    
    function loadVerified(bytes32 certHash) external view returns (ICertManager.VerifiedCert memory) {
        bytes memory data = verified[certHash];
        if (data.length == 0) {
            // Return empty struct if not found
            return ICertManager.VerifiedCert({
                ca: false,
                notAfter: 0,
                maxPathLen: 0,
                subjectHash: bytes32(0),
                pubKey: new bytes(0)
            });
        }
        return abi.decode(data, (ICertManager.VerifiedCert));
    }
    
    function isVerified(bytes32 certHash) external view returns (bool) {
        return verified[certHash].length > 0;
    }
}
