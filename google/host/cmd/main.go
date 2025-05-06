package main

import (
	"context"

	"github.com/EkamSinghPandher/Tee-Google/google/host/proxy"
	log "github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()
	log.Info("Starting google auth POC host service")

	go proxy.InitVsockToTcpProxy(ctx, 50001, 443, "https://www.googleapis.com")

	for {
	}
}
