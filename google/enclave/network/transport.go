package network

import (
	"bufio"
	"net/http"
	"net/http/httputil"

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
	reqDump, err := httputil.DumpRequest(req, false)
	if err == nil {
		log.Infof("Request being sent:\n%s", string(reqDump))
	}

	// Dial vsock connection
	log.Infof("Initiating vsock connection at vsock port: %d", v.Port)

	conn, err := vsock.Dial(v.CID, v.Port, &vsock.Config{})
	defer conn.Close()
	if err != nil {
		log.Errorf("Unable to initiate connection to the vsock with error: %v", err)
		return nil, err
	}

	// Send HTTP request over the connection
	if err := req.Write(conn); err != nil {
		log.Errorf("Unable to forward request to the vsock with error: %v", err)
		return nil, err
	}

	log.Infof("Request prepared: %+v", req)

	// Read the HTTP response
	response, err := http.ReadResponse(bufio.NewReader(conn), req)

	if err != nil {
		log.Errorf("Unable to get response from vsock with error: %v", err)
		return nil, err
	}

	log.Infof("Response received: %+v", response)
	return response, err
}
