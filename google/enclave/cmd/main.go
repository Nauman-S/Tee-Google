package main

import (
	client "github.com/EkamSinghPandher/Tee-Google/google/enclave/_client"
	"github.com/EkamSinghPandher/Tee-Google/google/enclave/attest"
	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"

	log "github.com/sirupsen/logrus"
)

func main() {
	log.Info("Starting google auth POC enclave service")
	network.InitGoogleHttpsClientWithTLSVsockTransport(50001)
	network.InitEthereumClientWithVsockTransport(50003)

	keys, err := network.GetGoogleKeys()

	if err != nil {
		log.Errorf("Error sending request through vsock with err: %v", err)
		return
	}

	log.Infof("Successfully fetched keys: %+v", keys)

	prepareAttestationPayload, err := attest.PrepareAttestationPayload(keys)
	if err != nil {
		log.Errorf("Error preparing attestation payload: %v", err)
	}
	log.Infof("Prepared attestation payload: %+v", prepareAttestationPayload)

	attestation, err := attest.GenerateMockAttestation(prepareAttestationPayload)
	if err != nil {
		log.Errorf("Error generating mock attestation: %v", err)
		return
	}
	log.Infof("Generated mock attestation: %d bytes", len(attestation))

	err = client.SubmitAttestationToBlockchain(attestation)
	if err != nil {
		log.Errorf("Error submitting attestation to blockchain: %v", err)
		return
	}

	for {

	}
}
