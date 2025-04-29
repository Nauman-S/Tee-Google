package main

import (
	"context"
	"fmt"
	"io"
	"net/http"

	"github.com/EkamSinghPandher/Tee-Google/google/host/proxy"
	log "github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()
	log.Info("Starting google auth POC host service")

	go proxy.InitVsockToTcpProxy(ctx, 50001, 8080, "localhost")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("Received request: %+v\n", r)
		body, _ := io.ReadAll(r.Body)
		fmt.Printf("Body: %s\n", body)
		w.Write([]byte("Hello from host\n"))
	})

	fmt.Println("Listening on :8080")
	http.ListenAndServe(":8080", nil)
}
