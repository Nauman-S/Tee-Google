package network

import (
	"crypto/rsa"
	"encoding/json"
	"fmt"
	"io"
	"math/big"

	log "github.com/sirupsen/logrus"
)

const googleJwksUrl = "https://www.googleapis.com/oauth2/v3/certs"

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
		return nil, fmt.Errorf("Error, non RSA key detected, key is of type: %s", jwk.Kty)
	}

	// Decode the base64url encoded modulus and exponent
	n, err := base64URLDecode(jwk.N)
	if err != nil {
		log.Errorf("Error decoding modulus: %v", err)
		return nil, fmt.Errorf("Error decoding modulus: %v", err)
	}

	e, err := base64URLDecode(jwk.E)
	if err != nil {
		log.Errorf("Error decoding exponent: %v", err)
		return nil, fmt.Errorf("Error decoding exponent: %v", err)
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
func GetGoogleKeys() (map[string]*rsa.PublicKey, error) {
	resp, err := googleClient.Get(googleJwksUrl)
	if err != nil {
		log.Errorf("Error fetching google cert with err: %+v", err)
		return nil, fmt.Errorf("Error fetching keys from google: %v", err)
	}

	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Errorf("Error reading response body: %v", err)
		return nil, fmt.Errorf("Error reading response body: %v", err)
	}

	// Parse the JWKS response
	var jwks JWKSResponse
	if err := json.Unmarshal(body, &jwks); err != nil {
		log.Errorf("error parsing JWKS: %v", err)
		return nil, fmt.Errorf("Error parsing JWKS: %v", err)
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
