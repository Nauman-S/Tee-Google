package attest

import (
	"crypto/rsa"
	"encoding/json"
	"fmt"
	"math/big"
	"testing"

	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"
	"github.com/fxamacker/cbor/v2"
	"github.com/stretchr/testify/assert"
)

func TestInjectRealKeysIntoAttestation(t *testing.T) {

	googleKeys := &network.GoogleKeys{
		JWKSKeys: make(map[string]*rsa.PublicKey),
		DKIMKeys: make(map[string]map[string]*rsa.PublicKey),
	}
	googleKeys.JWKSKeys["1"] = &rsa.PublicKey{
		N: big.NewInt(1),
		E: 65537,
	}

	googleKeys.DKIMKeys["example.com"] = make(map[string]*rsa.PublicKey)
	googleKeys.DKIMKeys["example.com"]["1"] = &rsa.PublicKey{
		N: big.NewInt(1),
		E: 65537,
	}

	payload, err := PrepareAttestationPayload(googleKeys)
	if err != nil {
		t.Fatalf("Failed to prepare payload: %v", err)
	}

	attestationBytes, err := GenerateMockAttestation(payload)
	if err != nil {
		t.Fatalf("Failed to generate mock attestation: %v", err)
	}

	fmt.Printf("New attestation len: %d\n", len(attestationBytes))
	payloadMap, err := parsePayload(attestationBytes)
	if err != nil {
		t.Fatalf("Failed to parse payload: %v", err)
	}

	userData, ok := payloadMap["user_data"]
	if !ok {
		t.Fatalf("User data does not exist in payload")
	}

	// user_data is stored as JSON bytes, need to unmarshal it
	userDataBytes, ok := userData.([]byte)
	if !ok {
		t.Fatalf("User data is not bytes, it's %T", userData)
	}

	var keyData map[string]interface{}
	err = json.Unmarshal(userDataBytes, &keyData)
	if err != nil {
		t.Fatalf("Failed to unmarshal user data JSON: %v", err)
	}

	for k, v := range keyData {
		switch k {
		case "dkim_keys":
			dkimMap := v.(map[string]interface{})
			assert.Equal(t, len(googleKeys.DKIMKeys), len(dkimMap))

			for domain, selectors := range dkimMap {
				selectorMap := selectors.(map[string]interface{})
				assert.Equal(t, len(googleKeys.DKIMKeys[domain]), len(selectorMap))

				for _, keyString := range selectorMap {
					assert.IsType(t, "", keyString, "DKIM key should be a base64 string")
					keyStr := keyString.(string)
					assert.Greater(t, len(keyStr), 10, "DKIM key string should be substantial")
				}
			}

		case "jwks_keys":
			jwksMap := v.(map[string]interface{})
			assert.Equal(t, len(googleKeys.JWKSKeys), len(jwksMap))

			for _, keyString := range jwksMap {
				assert.IsType(t, "", keyString, "JWKS key should be a base64 string")
				keyStr := keyString.(string)
				assert.Greater(t, len(keyStr), 10, "JWKS key string should be substantial")
			}

		case "provider":
			assert.Equal(t, "google", v)
		}
	}

	assert.Equal(t, len(keyData), 3, "Expected 3 items in keyData")
}

func parsePayload(payloadBytes []byte) (map[string]interface{}, error) {
	var err error

	var coseArray []interface{}
	err = cbor.Unmarshal(payloadBytes, &coseArray)
	if err != nil {
		return nil, fmt.Errorf("Failed to parse COSE array: %v", err)
	}
	if len(coseArray) != 4 {
		return nil, fmt.Errorf("COSE array should have 4 elements: {protected, unprotected, payload, signature} but was %v", coseArray)
	}

	payloadBytes, ok := coseArray[2].([]byte)
	if !ok {
		return nil, fmt.Errorf("payload should be a byte array")
	}

	var payloadMap map[string]interface{}
	err = cbor.Unmarshal(payloadBytes, &payloadMap)
	if err != nil {
		return nil, fmt.Errorf("Payload is not a CBOR map: %v\n", err)
	}
	for k, v := range payloadMap {
		switch vv := v.(type) {
		case []byte:
			fmt.Printf("   %s: %d bytes\n", k, len(vv))
		case string:
			fmt.Printf("   %s: %s\n", k, vv)
		case uint64:
			fmt.Printf("   %s: %d\n", k, vv)
		case map[interface{}]interface{}:
			fmt.Printf("   %s: map with %d entries\n", k, len(vv))
		case []interface{}:
			fmt.Printf("   %s: array with %d entries\n", k, len(vv))
		default:
			fmt.Printf("   %s: %T = %v\n", k, v, v)
		}
	}
	return payloadMap, nil
}
