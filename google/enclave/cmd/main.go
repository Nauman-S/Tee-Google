package main

import (
	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"
	log "github.com/sirupsen/logrus"
)

func main() {
	log.Info("Starting google auth POC enclave service")
	client := network.InitHttpsClientWithVsockTransport(50001)

	resp, err := client.Get("http://dummy/")

	if err != nil {
		log.Errorf("Error sending request through vsock with err: %v", err)
	}

	log.Infof("Successfully sent req with resp: %+v", resp)

	for {

	}
}
