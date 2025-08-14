package network

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net"
	"regexp"
	"strings"

	log "github.com/sirupsen/logrus"
)

const googleJwksUrl = "https://www.googleapis.com/oauth2/v3/certs"

// Combined response structure
type GoogleKeys struct {
	JWKSKeys map[string]*rsa.PublicKey `json:"jwks_keys"`
	DKIMKeys map[string]*rsa.PublicKey `json:"dkim_keys"`
}

// JWK represents a JSON Web Key
type JWK struct {
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
}

// Get a RSA Pubkey from the JWK struct
func (jwk *JWK) getRSAPubkey() (*rsa.PublicKey, error) {
	if jwk.Kty != "RSA" {
		log.Errorf("Error, non RSA key detected, key is of type: %s", jwk.Kty)
		return nil, fmt.Errorf("error, non RSA key detected, key is of type: %s", jwk.Kty)
	}

	// Decode the base64url encoded modulus and exponent
	n, err := base64URLDecode(jwk.N)
	if err != nil {
		log.Errorf("Error decoding modulus: %v", err)
		return nil, fmt.Errorf("error decoding modulus: %v", err)
	}

	e, err := base64URLDecode(jwk.E)
	if err != nil {
		log.Errorf("Error decoding exponent: %v", err)
		return nil, fmt.Errorf("error decoding exponent: %v", err)
	}

	// Convert exponent bytes to int
	var eInt int
	for i := 0; i < len(e); i++ {
		eInt = eInt<<8 | int(e[i])
	}

	// Create the RSA public key
	pubKey := &rsa.PublicKey{
		N: new(big.Int).SetBytes(n),
		E: eInt,
	}

	return pubKey, nil
}

// JWKSResponse represents the response from Google's JWKS endpoint
type JWKSResponse struct {
	Keys []JWK `json:"keys"`
}

// Get google RSA pubkeys from their endpoint
func GetGoogleKeys() (*GoogleKeys, error) {
	result := &GoogleKeys{
		JWKSKeys: make(map[string]*rsa.PublicKey),
		DKIMKeys: make(map[string]*rsa.PublicKey),
	}

	jwksKeys, err := getJWKSKeys()
	if err != nil {
		log.Errorf("Error fetching JWKS keys: %v", err)
	} else {
		result.JWKSKeys = jwksKeys
	}

	dkimKeys, err := getDKIMKeys()
	if err != nil {
		log.Errorf("Error fetching DKIM keys: %v", err)
	} else {
		result.DKIMKeys = dkimKeys
	}

	if len(result.JWKSKeys) == 0 && len(result.DKIMKeys) == 0 {
		return nil, fmt.Errorf("failed to fetch both JWKS and DKIM keys")
	}

	log.Infof("Successfully fetched %d JWKS keys and %d DKIM keys",
		len(result.JWKSKeys), len(result.DKIMKeys))

	return result, nil
}

func getDKIMKeys() (map[string]*rsa.PublicKey, error) {
	// Gmail DKIM selectors to try
	selectors := []string{"20230601"}
	domain := "gmail.com"

	keys := make(map[string]*rsa.PublicKey)

	for _, selector := range selectors {
		dkimDomain := fmt.Sprintf("%s._domainkey.%s", selector, domain)

		txtRecords, err := net.LookupTXT(dkimDomain)

		if err != nil {
			log.Warnf("DNS lookup failed for %s: %v", dkimDomain, err)
			continue
		}

		for _, record := range txtRecords {
			// Check if this is a DKIM record
			if strings.Contains(record, "k=rsa") && strings.Contains(record, "p=") {

				pubKey, err := parseDKIMRecord(record)
				if err != nil {
					log.Errorf("Failed to parse DKIM record for %s: %v", selector, err)
					continue
				}

				keys[selector] = pubKey
				break
			}
		}
	}

	if len(keys) == 0 {
		return nil, fmt.Errorf("no valid DKIM keys found for gmail.com")
	}

	return keys, nil
}

func parseDKIMRecord(record string) (*rsa.PublicKey, error) {
	// DKIM records can be split across multiple strings, so join them
	record = strings.ReplaceAll(record, "\" \"", "")
	record = strings.ReplaceAll(record, " ", "")

	// Extract the p= parameter (base64 encoded public key)
	re := regexp.MustCompile(`p=([A-Za-z0-9+/=]+)`)
	matches := re.FindStringSubmatch(record)
	if len(matches) < 2 {
		return nil, fmt.Errorf("no public key found in DKIM record")
	}

	// Decode base64 public key
	pubKeyBytes, err := base64.StdEncoding.DecodeString(matches[1])
	if err != nil {
		return nil, fmt.Errorf("failed to decode base64 public key: %v", err)
	}

	// Parse as RSA public key
	pubKeyInterface, err := x509.ParsePKIXPublicKey(pubKeyBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse public key: %v", err)
	}

	rsaPubKey, ok := pubKeyInterface.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("public key is not RSA type")
	}

	return rsaPubKey, nil
}

func getJWKSKeys() (map[string]*rsa.PublicKey, error) {
	resp, err := googleClient.Get(googleJwksUrl)
	if err != nil {
		log.Errorf("Error fetching google cert with err: %+v", err)
		return nil, fmt.Errorf("error fetching keys from google: %v", err)
	}

	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Errorf("Error reading response body: %v", err)
		return nil, fmt.Errorf("error reading response body: %v", err)
	}

	// Parse the JWKS response
	var jwks JWKSResponse
	if err := json.Unmarshal(body, &jwks); err != nil {
		log.Errorf("error parsing JWKS: %v", err)
		return nil, fmt.Errorf("error parsing JWKS: %v", err)
	}

	// Create a map to store public keys by kid
	keys := make(map[string]*rsa.PublicKey)

	// Convert JWKs to RSA public keys
	for _, jwk := range jwks.Keys {
		pubKey, err := jwk.getRSAPubkey()

		if err != nil {
			continue
		} else {
			keys[jwk.Kid] = pubKey
		}
	}

	return keys, nil
}
