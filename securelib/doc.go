package securelib

import (
	"encoding/hex"
	"time"

	jsoniter "github.com/json-iterator/go"
)

var json = jsoniter.ConfigCompatibleWithStandardLibrary

type Doc struct {
	RawData    []byte
	PubKey     []byte
	UserData   []byte
	PCRs       map[string][]byte
	ExpiryTime time.Time
}

func (d *Doc) Debug() string {
	docPRCs := map[string]string{}
	for k, v := range d.PCRs {
		// show PCR0 only in the debug output
		if k == "0" {
			docPRCs[k] = "0x" + hex.EncodeToString(v)
			break
		}
	}
	docMap := map[string]any{
		"rawData":    "0x" + hex.EncodeToString(d.RawData),
		"pubKey":     "0x" + hex.EncodeToString(d.PubKey),
		"userData":   "0x" + hex.EncodeToString(d.UserData),
		"pcrs":       docPRCs,
		"expiryTime": d.ExpiryTime.Format(time.RFC3339),
	}
	buf, _ := json.MarshalIndent(docMap, "", "  ")
	return string(buf)
}
