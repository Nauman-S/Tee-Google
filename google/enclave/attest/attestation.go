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
}

type AttestationPayload struct {
	Provider string                       `json:"provider"`
	JWKSKeys map[string]string            `json:"jwks_keys"` // kid -> base64 DER
	DKIMKeys map[string]map[string]string `json:"dkim_keys"` // domain -> selector -> base64 DER
}

func PrepareAttestationPayload(googleKeys *network.GoogleKeys) (*AttestationPayload, error) {
	payload := &AttestationPayload{
		Provider: "google",
		JWKSKeys: make(map[string]string),
		DKIMKeys: make(map[string]map[string]string),
	}

	// Convert JWKS RSA keys to base64 DER
	total_jwks_keys := 0
	for kid, rsaKey := range googleKeys.JWKSKeys {
		derBytes, err := x509.MarshalPKIXPublicKey(rsaKey)
		if err != nil {
			log.Warnf("Failed to marshal JWKS key %s: %v", kid, err)
			continue
		}
		payload.JWKSKeys[kid] = base64.StdEncoding.EncodeToString(derBytes)
		total_jwks_keys++
	}

	// Convert DKIM RSA keys to base64 DER
	total_dkim_keys := 0
	for domain, selectors := range googleKeys.DKIMKeys {
		for selector, rsaKey := range selectors {
			derBytes, err := x509.MarshalPKIXPublicKey(rsaKey)
			if err != nil {
				log.Warnf("Failed to marshal DKIM key %s: %v", selector, err)
				continue
			}
			if payload.DKIMKeys[domain] == nil {
				payload.DKIMKeys[domain] = make(map[string]string)
			}
			payload.DKIMKeys[domain][selector] = base64.StdEncoding.EncodeToString(derBytes)
			total_dkim_keys++
		}
	}

	log.Infof("Prepared attestation for provider: %s with %d JWKS and %d DKIM keys",
		payload.Provider, total_jwks_keys, total_dkim_keys)

	return payload, nil
}

func GenerateMockAttestation(payload *AttestationPayload) ([]byte, error) {

	// Convert to JSON for userData
	userDataBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %v", err)
	}
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
