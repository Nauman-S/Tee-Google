package main

import (
	"context"

	"github.com/EkamSinghPandher/Tee-Google/google/host/proxy"
	log "github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()
	log.Info("Starting google auth POC host service")

	// Existing Google API proxy
	go proxy.InitVsockToTcpProxy(ctx, 50001, 443, "https://www.googleapis.com")

	// New Ethereum RPC proxy - forward vsock port 50002 to anvil at localhost:8545
	go proxy.InitVsockToTcpProxy(ctx, 50003, 8545, "http://127.0.0.1")

	for {
	}
}
