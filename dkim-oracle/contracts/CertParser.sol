// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Asn1Decode, Asn1Ptr, LibAsn1Ptr} from "./Asn1Decode.sol";
import {LibBytes} from "./LibBytes.sol";

contract CertParser {
    using Asn1Decode for bytes;
    using LibAsn1Ptr for Asn1Ptr;
    using LibBytes for bytes;

    // OID constants (moved from CertManager)
    bytes32 public constant CERT_ALGO_OID = 0x53ce037f0dfaa43ef13b095f04e68a6b5e3f1519a01a3203a1e6440ba915b87e; // keccak256(hex"06082a8648ce3d040303")
    bytes32 public constant EC_PUB_KEY_OID = 0xb60fee1fd85f867dd7c8d16884a49a20287ebe4c0fb49294e9825988aa8e42b4; // keccak256(hex"2a8648ce3d0201")
    bytes32 public constant SECP_384_R1_OID = 0xbd74344bb507daeb9ed315bc535f24a236ccab72c5cd6945fb0efe5c037e2097; // keccak256(hex"2b81040022")
    bytes32 public constant BASIC_CONSTRAINTS_OID = 0x6351d72a43cb42fb9a2531a28608c278c89629f8f025b5f5dc705f3fe45e950a; // keccak256(hex"551d13")
    bytes32 public constant KEY_USAGE_OID = 0x45529d8772b07ebd6d507a1680da791f4a2192882bf89d518801579f7a5167d2; // keccak256(hex"551d0f")

    function parseTbs(bytes memory certificate, Asn1Ptr ptr, bool ca)
        external
        view
        returns (uint64 notAfter, int64 maxPathLen, bytes32 issuerHash, bytes32 subjectHash, bytes memory pubKey)
    {
        Asn1Ptr versionPtr = certificate.firstChildOf(ptr);
        Asn1Ptr vPtr = certificate.firstChildOf(versionPtr);
        Asn1Ptr serialPtr = certificate.nextSiblingOf(versionPtr);
        Asn1Ptr sigAlgoPtr = certificate.nextSiblingOf(serialPtr);

        require(certificate.keccak(sigAlgoPtr.content(), sigAlgoPtr.length()) == CERT_ALGO_OID, "invalid cert sig algo");
        uint256 version = certificate.uintAt(vPtr);
        // as extensions are used in cert, version should be 3 (value 2) as per https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.1
        require(version == 2, "version should be 3");

        (notAfter, maxPathLen, issuerHash, subjectHash, pubKey) = parseTbsInner(certificate, sigAlgoPtr, ca);
    }

    function parseTbsInner(bytes memory certificate, Asn1Ptr sigAlgoPtr, bool ca)
        public
        view
        returns (uint64 notAfter, int64 maxPathLen, bytes32 issuerHash, bytes32 subjectHash, bytes memory pubKey)
    {
        Asn1Ptr issuerPtr = certificate.nextSiblingOf(sigAlgoPtr);
        issuerHash = certificate.keccak(issuerPtr.content(), issuerPtr.length());
        Asn1Ptr validityPtr = certificate.nextSiblingOf(issuerPtr);
        Asn1Ptr subjectPtr = certificate.nextSiblingOf(validityPtr);
        subjectHash = certificate.keccak(subjectPtr.content(), subjectPtr.length());
        Asn1Ptr subjectPublicKeyInfoPtr = certificate.nextSiblingOf(subjectPtr);
        Asn1Ptr extensionsPtr = certificate.nextSiblingOf(subjectPublicKeyInfoPtr);

        if (certificate[extensionsPtr.header()] == 0x81) {
            // skip optional issuerUniqueID
            extensionsPtr = certificate.nextSiblingOf(extensionsPtr);
        }
        if (certificate[extensionsPtr.header()] == 0x82) {
            // skip optional subjectUniqueID
            extensionsPtr = certificate.nextSiblingOf(extensionsPtr);
        }

        notAfter = verifyValidity(certificate, validityPtr);
        maxPathLen = verifyExtensions(certificate, extensionsPtr, ca);
        pubKey = parsePubKey(certificate, subjectPublicKeyInfoPtr);
    }

    function parsePubKey(bytes memory certificate, Asn1Ptr subjectPublicKeyInfoPtr)
        public
        pure
        returns (bytes memory subjectPubKey)
    {
        Asn1Ptr pubKeyAlgoPtr = certificate.firstChildOf(subjectPublicKeyInfoPtr);
        Asn1Ptr pubKeyAlgoIdPtr = certificate.firstChildOf(pubKeyAlgoPtr);
        Asn1Ptr algoParamsPtr = certificate.nextSiblingOf(pubKeyAlgoIdPtr);
        Asn1Ptr subjectPublicKeyPtr = certificate.nextSiblingOf(pubKeyAlgoPtr);
        Asn1Ptr subjectPubKeyPtr = certificate.bitstring(subjectPublicKeyPtr);

        require(
            certificate.keccak(pubKeyAlgoIdPtr.content(), pubKeyAlgoIdPtr.length()) == EC_PUB_KEY_OID,
            "invalid cert algo id"
        );
        require(
            certificate.keccak(algoParamsPtr.content(), algoParamsPtr.length()) == SECP_384_R1_OID,
            "invalid cert algo param"
        );

        uint256 end = subjectPubKeyPtr.content() + subjectPubKeyPtr.length();
        subjectPubKey = certificate.slice(end - 96, 96);
    }

    function verifyValidity(bytes memory certificate, Asn1Ptr validityPtr) public view returns (uint64 notAfter) {
        Asn1Ptr notBeforePtr = certificate.firstChildOf(validityPtr);
        Asn1Ptr notAfterPtr = certificate.nextSiblingOf(notBeforePtr);

        uint256 notBefore = certificate.timestampAt(notBeforePtr);
        notAfter = uint64(certificate.timestampAt(notAfterPtr));

        require(notBefore <= block.timestamp, "certificate not valid yet");
        require(notAfter >= block.timestamp, "certificate not valid anymore");
    }

    function verifyExtensions(bytes memory certificate, Asn1Ptr extensionsPtr, bool ca)
        public
        pure
        returns (int64 maxPathLen)
    {
        require(certificate[extensionsPtr.header()] == 0xa3, "invalid extensions");
        extensionsPtr = certificate.firstChildOf(extensionsPtr);
        Asn1Ptr extensionPtr = certificate.firstChildOf(extensionsPtr);
        uint256 end = extensionsPtr.content() + extensionsPtr.length();
        bool basicConstraintsFound = false;
        bool keyUsageFound = false;
        maxPathLen = -1;

        while (true) {
            Asn1Ptr oidPtr = certificate.firstChildOf(extensionPtr);
            bytes32 oid = certificate.keccak(oidPtr.content(), oidPtr.length());

            if (oid == BASIC_CONSTRAINTS_OID || oid == KEY_USAGE_OID) {
                Asn1Ptr valuePtr = certificate.nextSiblingOf(oidPtr);

                if (certificate[valuePtr.header()] == 0x01) {
                    // skip optional critical bool
                    require(valuePtr.length() == 1, "invalid critical bool value");
                    valuePtr = certificate.nextSiblingOf(valuePtr);
                }

                valuePtr = certificate.octetString(valuePtr);

                if (oid == BASIC_CONSTRAINTS_OID) {
                    basicConstraintsFound = true;
                    maxPathLen = verifyBasicConstraintsExtension(certificate, valuePtr, ca);
                } else {
                    keyUsageFound = true;
                    verifyKeyUsageExtension(certificate, valuePtr, ca);
                }
            }

            if (extensionPtr.content() + extensionPtr.length() == end) {
                break;
            }
            extensionPtr = certificate.nextSiblingOf(extensionPtr);
        }

        require(basicConstraintsFound, "basicConstraints not found");
        require(keyUsageFound, "keyUsage not found");
        require(ca || maxPathLen == -1, "maxPathLen must be undefined for client cert");
    }

    function verifyBasicConstraintsExtension(bytes memory certificate, Asn1Ptr valuePtr, bool ca)
        public
        pure
        returns (int64 maxPathLen)
    {
        maxPathLen = -1;
        Asn1Ptr basicConstraintsPtr = certificate.firstChildOf(valuePtr);
        bool isCA;
        if (certificate[basicConstraintsPtr.header()] == 0x01) {
            require(basicConstraintsPtr.length() == 1, "invalid isCA bool value");
            isCA = certificate[basicConstraintsPtr.content()] == 0xff;
            basicConstraintsPtr = certificate.nextSiblingOf(basicConstraintsPtr);
        }
        require(ca == isCA, "isCA must be true for CA certs");
        if (certificate[basicConstraintsPtr.header()] == 0x02) {
            maxPathLen = int64(uint64(certificate.uintAt(basicConstraintsPtr)));
        }
    }

    function verifyKeyUsageExtension(bytes memory certificate, Asn1Ptr valuePtr, bool ca) public pure {
        uint256 value = certificate.bitstringUintAt(valuePtr);
        // bits are reversed (DigitalSignature 0x01 => 0x80, CertSign 0x32 => 0x04)
        if (ca) {
            require(value & 0x04 == 0x04, "CertSign must be present");
        } else {
            require(value & 0x80 == 0x80, "DigitalSignature must be present");
        }
    }
}
