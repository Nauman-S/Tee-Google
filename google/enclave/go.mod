module github.com/EkamSinghPandher/Tee-Google/google/enclave

replace github.com/EkamSinghPandher/Tee-Google/vsock => ./../../vsock

go 1.23.0

require (
	github.com/EkamSinghPandher/Tee-Google/vsock v0.0.0-00010101000000-000000000000
	github.com/sirupsen/logrus v1.9.3
)

require (
	golang.org/x/net v0.39.0 // indirect
	golang.org/x/sync v0.13.0 // indirect
	golang.org/x/sys v0.32.0 // indirect
)
