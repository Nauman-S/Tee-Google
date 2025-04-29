package network

import (
	"bufio"
	"net/http"

	"github.com/EkamSinghPandher/Tee-Google/vsock"
	log "github.com/sirupsen/logrus"
)

// Roundtripper to overwrite the transport layer
type VsockRoundTripper struct {
	CID  uint32
	Port uint32
}

// Implement the round trip function, replacing tcp connection with a vsock one
func (v *VsockRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	// Dial vsock connection
	log.Infof("Initiating vsock connection at vsock port: %d", v.Port)
	conn, err := vsock.Dial(v.CID, v.Port, &vsock.Config{})
	if err != nil {
		log.Errorf("Unable to initiate connection to the vsock with error: %v", err)
		return nil, err
	}

	// Send HTTP request over the connection
	if err := req.Write(conn); err != nil {
		log.Errorf("Unable to forward request to the vsock with error: %v", err)
		return nil, err
	}

	// Read the HTTP response
	return http.ReadResponse(bufio.NewReader(conn), req)
}
