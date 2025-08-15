package attest

import (
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"
	"github.com/EkamSinghPandher/Tee-Google/securelib"

	log "github.com/sirupsen/logrus"
)

func init() {
	securelib.InitMock()
	log.Info("Attestation module initialized")
}

type AttestationPayload struct {
	Provider string            `json:"provider"`
	JWKSKeys map[string]string `json:"jwks_keys"` // kid -> base64 DER
	DKIMKeys map[string]string `json:"dkim_keys"` // selector -> base64 DER
}

func PrepareAttestationPayload(googleKeys *network.GoogleKeys) (*AttestationPayload, error) {
	payload := &AttestationPayload{
		Provider: "google",
		JWKSKeys: make(map[string]string),
		DKIMKeys: make(map[string]string),
	}

	// Convert JWKS RSA keys to base64 DER
	for kid, rsaKey := range googleKeys.JWKSKeys {
		derBytes, err := x509.MarshalPKIXPublicKey(rsaKey)
		if err != nil {
			log.Warnf("Failed to marshal JWKS key %s: %v", kid, err)
			continue
		}
		payload.JWKSKeys[kid] = base64.StdEncoding.EncodeToString(derBytes)
	}

	// Convert DKIM RSA keys to base64 DER
	for selector, rsaKey := range googleKeys.DKIMKeys {
		derBytes, err := x509.MarshalPKIXPublicKey(rsaKey)
		if err != nil {
			log.Warnf("Failed to marshal DKIM key %s: %v", selector, err)
			continue
		}
		payload.DKIMKeys[selector] = base64.StdEncoding.EncodeToString(derBytes)
	}

	log.Infof("Prepared attestation for provider: %s with %d JWKS and %d DKIM keys",
		payload.Provider, len(payload.JWKSKeys), len(payload.DKIMKeys))

	return payload, nil
}

func GenerateMockAttestation(payload *AttestationPayload) ([]byte, error) {

	// Convert to JSON for userData
	userDataBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %v", err)
	}

	log.Infof("Prepared attestation userData: %d bytes", len(userDataBytes))

	// Generate mock attestation
	manager := securelib.GetManager()
	return manager.Attest(nil, userDataBytes)
}

func ParseAttestation(attestation []byte) (*securelib.Doc, error) {
	manager := securelib.GetManager()
	doc, err := manager.Parse(attestation)
	if err != nil {
		return nil, fmt.Errorf("failed to parse attestation: %v", err)
	}

	log.Infof("Parsed attestation with rawData: %d bytes, pubKey: %d bytes, userData: %d bytes",
		len(doc.RawData), len(doc.PubKey), len(doc.UserData))

	return doc, nil
}
