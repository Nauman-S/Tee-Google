package network

import (
	"context"
	"net/http"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	log "github.com/sirupsen/logrus"
)

var ethereumClient *ethclient.Client

func InitEthereumClientWithVsockTransport(vsockPort uint32) error {

	transport := &VsockHTTPRoundTripper{
		CID:  3, // Host CID
		Port: vsockPort,
	}

	httpClient := &http.Client{
		Transport: transport,
	}

	rpcClient, err := rpc.DialOptions(
		context.Background(),
		"http://127.0.0.1:8545",
		rpc.WithHTTPClient(httpClient),
	)
	if err != nil {
		return err
	}

	ethereumClient = ethclient.NewClient(rpcClient)
	log.Infof("Ethereum client initialized with VSock transport on port %d", vsockPort)
	return nil
}

func GetEthereumClient() *ethclient.Client {
	return ethereumClient
}
