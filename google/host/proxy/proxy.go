package proxy

import (
	vsockproxy "google/vsock/proxy"

	log "github.com/sirupsen/logrus"
)

// This function listens to the Vsock port provided and forwards the traffic to the TCP port provided.
func InitVsockToTcpProxy(vsockPort uint32, tcpPort uint32) {
	log.Infof("Listening to vsock at port: %v", vsockPort)
	vsockproxy.NewVsockProxy(ctx, "api.telegram.org", 443, vsockPort)
}
