package main

import (
	"context"
	"encoding/hex"
	"fmt"

	"github.com/apache/thrift/lib/go/thrift"
)

// Emit header frames for fixed messages, so the MoonBit side can compare byte for byte.
func frame(compact bool, headers map[string]string, transforms []thrift.THeaderTransformID) string {
	mb := thrift.NewTMemoryBuffer()
	id := thrift.THeaderProtocolBinary
	if compact {
		id = thrift.THeaderProtocolCompact
	}
	cfg := &thrift.TConfiguration{THeaderProtocolID: &id}
	t := thrift.NewTHeaderTransportConf(mb, cfg)
	var proto thrift.TProtocol
	if compact {
		proto = thrift.NewTCompactProtocolConf(t, cfg)
	} else {
		proto = thrift.NewTBinaryProtocolConf(t, cfg)
	}
	// Go leaves the meta sequence id at zero unless it is set, so it is set here: the format
	// says the field carries the message's id, which is what the other implementations write.
	t.SequenceID = 7
	for k, v := range headers {
		t.SetWriteHeader(k, v)
	}
	for _, tr := range transforms {
		t.AddTransform(tr)
	}
	ctx := context.Background()
	proto.WriteMessageBegin(ctx, "ping", thrift.CALL, 7)
	proto.WriteStructBegin(ctx, "ping_args")
	proto.WriteFieldBegin(ctx, "n", thrift.I32, 1)
	proto.WriteI32(ctx, 42)
	proto.WriteFieldEnd(ctx)
	proto.WriteFieldStop(ctx)
	proto.WriteStructEnd(ctx)
	if err := proto.Flush(ctx); err != nil {
		panic(err)
	}
	return hex.EncodeToString(mb.Bytes())
}

func main() {
	fmt.Println("binary plain     ", frame(false, nil, nil))
	fmt.Println("compact plain    ", frame(true, nil, nil))
	fmt.Println("binary header    ", frame(false, map[string]string{"trace-id": "abc"}, nil))
	fmt.Println("binary zlib      ", frame(false, nil, []thrift.THeaderTransformID{thrift.TransformZlib}))
}
