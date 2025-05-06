package network

import (
	"net/http"
	"time"
)

var googleClient *http.Client

func InitGoogleHttpsClientWithVsockTransport(vsockPort uint32) {
	googleClient = &http.Client{
		Transport: &VsockRoundTripper{
			CID:  3,         // Host CID from guest
			Port: vsockPort, // Arbitrary vsock port
		},
		Timeout: 5 * time.Second,
	}
}
