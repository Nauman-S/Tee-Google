# Tee-Google

**Trusted Execution Environment (TEE) for Google service key attestation and on-chain validation.**

## Purpose

This system securely extracts and validates Google DKIM/JWKS keys using AWS Nitro enclaves, then stores them on Ethereum with cryptographic proof of authenticity.

**Flow:** `Google APIs` → `TEE Enclave` → `Attestation Generation` → `Ethereum Validation` → `On-chain Key Storage`

## Quick Start

### 1. Start Local Blockchain
```bash
anvil --timestamp 1742270400 --gas-limit 60000000
```

### 2. Deploy Smart Contracts
```bash
source .env
cd dkim-oracle
forge script src/deploy/DeployDKIMOracleReduced.s.sol --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. Start Host Proxy (Terminal 2)
```bash
source .env
cd google/host
go run cmd/main.go
```

### 4. Run TEE Enclave (Terminal 3)
```bash
source .env
cd google/enclave  
go run cmd/main.go
```

## Architecture

- **VSock Communication**: Secure enclave ↔ host communication
- **AWS Nitro Attestation**: Cryptographic proof of execution environment
- **Gas**: 54M gas for complete attestation validation
- **Transaction Size**: ~4.5kB

## Key Components

- `dkim-oracle/`: Solidity contracts for certificate and attestation validation
- `google/enclave/`: TEE service for key extraction and attestation
- `google/host/`: Proxy service for blockchain communication
- `vsock/`: Virtual socket implementation for secure communication

## Contract Addresses (Local)

After deployment, contracts are available at deterministic addresses:
- **DKIMOracle**: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`

## Testing

```bash
# Test smart contracts
cd dkim-oracle && forge test

# Test with real attestation data  
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "decodeAndValidateAttestation(bytes)" "0x$(cat payload/mock.hex)" --gas-limit 100000000
```