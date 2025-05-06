package network

import (
	"crypto/tls"
	"net/http"

	log "github.com/sirupsen/logrus"
)

var googleClient *http.Client

// InitGoogleHttpsClientWithTLSVsockTransport creates an HTTP client that uses TLS over VSock
func InitGoogleHttpsClientWithTLSVsockTransport(vsockPort uint32) {
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
		ServerName: "www.googleapis.com",
	}

	transport := &VsockTLSRoundTripper{
		CID:       3, // Host CID
		Port:      vsockPort,
		TLSConfig: tlsConfig,
	}

	googleClient = &http.Client{
		Transport: transport,
	}

	log.Infof("Google HTTPS client initialized with TLS VSock transport on port %d", vsockPort)
}
