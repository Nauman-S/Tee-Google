package network

import (
	"net/http"
	"time"
)

func InitHttpsClientWithVsockTransport(vsockPort uint32) *http.Client {
	client := &http.Client{
		Transport: &VsockRoundTripper{
			CID:  3,         // Host CID from guest
			Port: vsockPort, // Arbitrary vsock port
		},
		Timeout: 5 * time.Second,
	}

	return client
}
