package client

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"time"

	"github.com/EkamSinghPandher/Tee-Google/google/enclave/network"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"

	log "github.com/sirupsen/logrus"
)

func SubmitAttestationToBlockchain(attestation []byte) error {
	client := network.GetEthereumClient()
	if client == nil {
		return fmt.Errorf("ethereum client not initialized")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get chain ID
	chainID, err := client.ChainID(ctx)
	if err != nil {
		return fmt.Errorf("failed to get chain ID: %v", err)
	}
	log.Infof("Connected to chain ID: %s", chainID.String())

	// Get latest block to verify connection
	block, err := client.BlockNumber(ctx)
	if err != nil {
		return fmt.Errorf("failed to get block number: %v", err)
	}
	log.Infof("Latest block: %d", block)

	submitToDKIMOracle(client, attestation)

	return nil
}

func submitToDKIMOracle(client *ethclient.Client, attestation []byte) error {
	log.Infof("Submitting %d bytes of attestation data to blockchain", len(attestation))

	contractAddress := common.HexToAddress("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9") // DKIMOracle contract address (deployed with split architecture)

	// Get private key from environment (same as deploy script)
	privateKeyHex := os.Getenv("PRIVATE_KEY")
	if privateKeyHex == "" {
		// Fallback to Anvil test key for development
		privateKeyHex = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
		log.Warn("No PRIVATE_KEY env var set, using default Anvil key")
	}

	privateKey, err := crypto.HexToECDSA(privateKeyHex)
	if err != nil {
		return fmt.Errorf("invalid private key: %v", err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, big.NewInt(31337))
	if err != nil {
		return fmt.Errorf("failed to create transactor: %v", err)
	}

	// Set gas limit to 55M gas (should use alittle over 50M for first time validation)
	gas_limit := uint64(54000000)
	auth.GasLimit = gas_limit

	log.Infof("Calling DKIMOracle contract at %s with attestation: %d bytes", contractAddress.Hex(), len(attestation))
	log.Infof("Using account address: %s", crypto.PubkeyToAddress(privateKey.PublicKey).Hex())

	methodSig := crypto.Keccak256([]byte("decodeAndValidateAttestation(bytes)"))[:4]

	// ABI encode the attestation data
	// For bytes parameter: offset(32) + length(32) + data + padding
	offset := make([]byte, 32)
	big.NewInt(32).FillBytes(offset) // Offset to data start (32 bytes)

	length := make([]byte, 32)
	big.NewInt(int64(len(attestation))).FillBytes(length)

	// Calculate padding needed to make attestation data 32-byte aligned
	padding := 32 - (len(attestation) % 32)
	if padding == 32 {
		padding = 0
	}

	// Build call data: methodSig + offset + length + data + padding
	callData := append(methodSig, offset...)
	callData = append(callData, length...)
	callData = append(callData, attestation...)
	callData = append(callData, make([]byte, padding)...)

	log.Infof("Sending transaction with %d bytes of call data...", len(callData))

	// Send transaction
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Get nonce
	fromAddress := crypto.PubkeyToAddress(privateKey.PublicKey)
	nonce, err := client.PendingNonceAt(ctx, fromAddress)
	if err != nil {
		return fmt.Errorf("failed to get nonce: %v", err)
	}

	// Get gas price
	gasPrice, err := client.SuggestGasPrice(ctx)
	if err != nil {
		return fmt.Errorf("failed to get gas price: %v", err)
	}

	// Create transaction
	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &contractAddress,
		Value:    big.NewInt(0),
		Gas:      gas_limit,
		GasPrice: gasPrice,
		Data:     callData,
	})

	// Sign transaction
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(big.NewInt(31337)), privateKey)
	if err != nil {
		return fmt.Errorf("failed to sign transaction: %v", err)
	}

	// Send transaction
	err = client.SendTransaction(ctx, signedTx)
	if err != nil {
		return fmt.Errorf("failed to send transaction: %v", err)
	}

	log.Infof("Transaction sent! Hash: %s", signedTx.Hash().Hex())
	log.Infof("Waiting for transaction confirmation...")

	// Wait for transaction receipt
	receipt, err := bind.WaitMined(ctx, client, signedTx)
	if err != nil {
		return fmt.Errorf("transaction failed: %v", err)
	}

	if receipt.Status == 1 {
		log.Infof("✅ Transaction successful! Block: %d, Gas used: %d", receipt.BlockNumber.Uint64(), receipt.GasUsed)
		log.Infof("✅ Attestation validated and processed on-chain!")
	} else {
		log.Errorf("❌ Transaction receipt: %v", receipt)
		return fmt.Errorf("transaction execution failed")
	}

	return nil
}
