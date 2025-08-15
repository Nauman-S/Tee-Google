module github.com/EkamSinghPandher/Tee-Google/google/enclave

replace github.com/EkamSinghPandher/Tee-Google/vsock => ./../../vsock

replace github.com/EkamSinghPandher/Tee-Google/securelib => ./../../securelib

go 1.23.4

require (
	github.com/EkamSinghPandher/Tee-Google/securelib v0.0.0-00010101000000-000000000000
	github.com/EkamSinghPandher/Tee-Google/vsock v0.0.0-00010101000000-000000000000
	github.com/sirupsen/logrus v1.9.3
)

require (
	github.com/fxamacker/cbor/v2 v2.2.0 // indirect
	github.com/hf/nitrite v0.0.0-20241225144000-c2d5d3c4f303 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/modern-go/concurrent v0.0.0-20180228061459-e0a39a4cb421 // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	golang.org/x/net v0.39.0 // indirect
	golang.org/x/sync v0.13.0 // indirect
	golang.org/x/sys v0.32.0 // indirect
)
