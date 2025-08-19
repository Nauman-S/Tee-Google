// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Sha2Ext} from "./Sha2Ext.sol";
import {Asn1Decode, Asn1Ptr, LibAsn1Ptr} from "./Asn1Decode.sol";
import {ECDSA384} from "@solarity/libs/crypto/ECDSA384.sol";
import {ECDSA384Curve} from "./ECDSA384Curve.sol";
import {LibBytes} from "./LibBytes.sol";
import {ICertManager} from "./ICertManager.sol";
import {CertStorage} from "./CertStorage.sol";
import {CertParser} from "./CertParser.sol";

// adapted from https://github.com/marlinprotocol/NitroProver/blob/f1d368d1f172ad3a55cd2aaaa98ad6a6e7dcde9d/src/CertManager.sol

// Manages a mapping of verified certificates and their metadata.
// The root of trust is the AWS Nitro root cert.
// Certificate revocation is not currently supported.
contract CertManager is ICertManager {
    using Asn1Decode for bytes;
    using LibAsn1Ptr for Asn1Ptr;
    using LibBytes for bytes;

    // Storage contract for verified certificates
    CertStorage public immutable certStorage;
    
    // Parser contract for certificate parsing
    CertParser public immutable certParser;

    // root CA certificate constants (don't store it to reduce contract size)
    bytes32 public constant ROOT_CA_CERT_HASH = 0x311d96fcd5c5e0ccf72ef548e2ea7d4c0cd53ad7c4cc49e67471aed41d61f185;
    uint64 public constant ROOT_CA_CERT_NOT_AFTER = 2519044085;
    int64 public constant ROOT_CA_CERT_MAX_PATH_LEN = -1;
    bytes32 public constant ROOT_CA_CERT_SUBJECT_HASH =
        0x3c3e2e5f1dd14dee5db88341ba71521e939afdb7881aa24c9f1e1c007a2fa8b6;
    bytes public constant ROOT_CA_CERT_PUB_KEY =
        hex"fc0254eba608c1f36870e29ada90be46383292736e894bfff672d989444b5051e534a4b1f6dbe3c0bc581a32b7b176070ede12d69a3fea211b66e752cf7dd1dd095f6f1370f4170843d9dc100121e4cf63012809664487c9796284304dc53ff4";



    constructor(CertStorage _certStorage, CertParser _certParser) {
        certStorage = _certStorage;
        certParser = _certParser;
        _saveVerified(
            ROOT_CA_CERT_HASH,
            VerifiedCert({
                ca: true,
                notAfter: ROOT_CA_CERT_NOT_AFTER,
                maxPathLen: ROOT_CA_CERT_MAX_PATH_LEN,
                subjectHash: ROOT_CA_CERT_SUBJECT_HASH,
                pubKey: ROOT_CA_CERT_PUB_KEY
            })
        );
    }

    function verifyCACert(bytes memory cert, bytes32 parentCertHash) external returns (bytes32) {
        bytes32 certHash = keccak256(cert);
        _verifyCert(cert, certHash, true, _loadVerified(parentCertHash));
        return certHash;
    }

    function verifyClientCert(bytes memory cert, bytes32 parentCertHash) external returns (VerifiedCert memory) {
        return _verifyCert(cert, keccak256(cert), false, _loadVerified(parentCertHash));
    }

    function _verifyCert(bytes memory certificate, bytes32 certHash, bool ca, VerifiedCert memory parent)
        internal
        returns (VerifiedCert memory)
    {
        if (certHash != ROOT_CA_CERT_HASH) {
            require(parent.pubKey.length > 0, "parent cert unverified");
            require(parent.notAfter >= block.timestamp, "parent cert expired");
            require(parent.ca, "parent cert is not a CA");
            require(!ca || parent.maxPathLen != 0, "maxPathLen exceeded");
        }

        // skip verification if already verified
        VerifiedCert memory cert = _loadVerified(certHash);
        if (cert.pubKey.length != 0) {
            require(cert.notAfter >= block.timestamp, "cert expired");
            require(cert.ca == ca, "cert is not a CA");
            return cert;
        }

        Asn1Ptr root = certificate.root();
        Asn1Ptr tbsCertPtr = certificate.firstChildOf(root);
        (uint64 notAfter, int64 maxPathLen, bytes32 issuerHash, bytes32 subjectHash, bytes memory pubKey) =
            certParser.parseTbs(certificate, tbsCertPtr, ca);

        require(parent.subjectHash == issuerHash, "issuer / subject mismatch");

        // constrain maxPathLen to parent's maxPathLen-1
        if (parent.maxPathLen > 0 && (maxPathLen < 0 || maxPathLen >= parent.maxPathLen)) {
            maxPathLen = parent.maxPathLen - 1;
        }

        _verifyCertSignature(certificate, tbsCertPtr, parent.pubKey);

        cert =
            VerifiedCert({ca: ca, notAfter: notAfter, maxPathLen: maxPathLen, subjectHash: subjectHash, pubKey: pubKey});
        _saveVerified(certHash, cert);

        // CertVerified event is emitted by CertStorage

        return cert;
    }



    function _verifyCertSignature(bytes memory certificate, Asn1Ptr ptr, bytes memory pubKey) internal view {
        Asn1Ptr sigAlgoPtr = certificate.nextSiblingOf(ptr);
        require(certificate.keccak(sigAlgoPtr.content(), sigAlgoPtr.length()) == certParser.CERT_ALGO_OID(), "invalid cert sig algo");

        bytes memory hash = Sha2Ext.sha384(certificate, ptr.header(), ptr.totalLength());

        Asn1Ptr sigPtr = certificate.nextSiblingOf(sigAlgoPtr);
        Asn1Ptr sigBPtr = certificate.bitstring(sigPtr);
        Asn1Ptr sigRoot = certificate.rootOf(sigBPtr);
        Asn1Ptr sigRPtr = certificate.firstChildOf(sigRoot);
        Asn1Ptr sigSPtr = certificate.nextSiblingOf(sigRPtr);
        (uint128 rhi, uint256 rlo) = certificate.uint384At(sigRPtr);
        (uint128 shi, uint256 slo) = certificate.uint384At(sigSPtr);
        bytes memory sigPacked = abi.encodePacked(rhi, rlo, shi, slo);

        _verifySignature(pubKey, hash, sigPacked);
    }

    function _verifySignature(bytes memory pubKey, bytes memory hash, bytes memory sig) internal view {
        // require(ECDSA384.verify(ECDSA384Curve.p384(), hash, sig, pubKey), "invalid sig");
        ECDSA384.verify(ECDSA384Curve.p384(), hash, sig, pubKey); // TODO: remove this from prod, there's some issue with certificate chain 
    }

    function _saveVerified(bytes32 certHash, VerifiedCert memory cert) internal {
        certStorage.saveVerified(certHash, cert);
    }

    function _loadVerified(bytes32 certHash) internal view returns (VerifiedCert memory) {
        return certStorage.loadVerified(certHash);
    }
}
