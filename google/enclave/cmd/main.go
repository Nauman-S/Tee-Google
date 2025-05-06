package main

import (
	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"
	log "github.com/sirupsen/logrus"
)

func main() {
	log.Info("Starting google auth POC enclave service")
	network.InitGoogleHttpsClientWithVsockTransport(50001)

	keys, err := network.GetGoogleKeys()

	if err != nil {
		log.Errorf("Error sending request through vsock with err: %v", err)
	}

	log.Infof("Successfully fetched keys: %+v", keys)

	for {

	}
}
