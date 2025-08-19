package securelib

import (
	"fmt"

	"github.com/fxamacker/cbor/v2"
)

func InjectCustomDataIntoAttestation(attestationBytes []byte, userDataBytes []byte) ([]byte, error) {
	var coseArray []interface{}
	err := cbor.Unmarshal(attestationBytes, &coseArray)
	if err != nil {
		return nil, fmt.Errorf("failed to parse COSE array: %v", err)
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
		return nil, fmt.Errorf("payload is not a CBOR map: %v", err)
	}

	payloadMap["user_data"] = userDataBytes

	newPayloadBytes, err := cbor.Marshal(payloadMap)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal new payload: %v", err)
	}

	newCoseArray := []interface{}{
		coseArray[0],    // protected headers
		coseArray[1],    // unprotected headers
		newPayloadBytes, // modified payload
		coseArray[3],    // signature (will be invalid, but OK for testing)
	}

	newAttestationBytes, err := cbor.Marshal(newCoseArray)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal new COSE array: %v", err)
	}

	return newAttestationBytes, nil
}
