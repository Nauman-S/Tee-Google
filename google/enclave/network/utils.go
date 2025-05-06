package network

import (
	"encoding/base64"
	"strings"
)

// Helper function to decode base64URL to bytes
func base64URLDecode(s string) ([]byte, error) {
	// Replace URL encoding specific characters
	s = strings.Replace(s, "-", "+", -1)
	s = strings.Replace(s, "_", "/", -1)

	// Add padding if needed
	if len(s)%4 != 0 {
		s += strings.Repeat("=", 4-len(s)%4)
	}

	return base64.StdEncoding.DecodeString(s)
}
