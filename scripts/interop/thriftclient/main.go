// An Apache Thrift client that calls the moonrpc Thrift server: TBinaryProtocol over
// TFramedTransport, the same two methods `thriftd` serves.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/apache/thrift/lib/go/thrift"
)

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func expect(ok bool, what string) {
	if !ok {
		fail("mismatch: %s", what)
	}
	fmt.Printf("ok  %s\n", what)
}

func dial(addr string) (thrift.TTransport, thrift.TProtocol) {
	conf := &thrift.TConfiguration{}
	socket := thrift.NewTSocketConf(addr, conf)
	trans := thrift.NewTFramedTransportConf(socket, conf)
	if err := trans.Open(); err != nil {
		fail("open: %v", err)
	}
	return trans, thrift.NewTBinaryProtocolConf(trans, conf)
}

func call(ctx context.Context, trans thrift.TTransport, p thrift.TProtocol, name string, seq int32, write func() error, want thrift.TType) any {
	if err := p.WriteMessageBegin(ctx, name, thrift.CALL, seq); err != nil {
		fail("%s begin: %v", name, err)
	}
	if err := p.WriteStructBegin(ctx, name+"_args"); err != nil {
		fail("%s struct: %v", name, err)
	}
	if err := write(); err != nil {
		fail("%s args: %v", name, err)
	}
	if err := p.WriteFieldStop(ctx); err != nil {
		fail("%s stop: %v", name, err)
	}
	if err := p.WriteStructEnd(ctx); err != nil {
		fail("%s end: %v", name, err)
	}
	if err := p.WriteMessageEnd(ctx); err != nil {
		fail("%s message end: %v", name, err)
	}
	if err := trans.Flush(ctx); err != nil {
		fail("%s flush: %v", name, err)
	}
	_, mtype, _, err := p.ReadMessageBegin(ctx)
	if err != nil {
		fail("%s reply begin: %v", name, err)
	}
	if mtype != thrift.REPLY {
		fail("%s: message type %d, not a reply", name, mtype)
	}
	if _, err := p.ReadStructBegin(ctx); err != nil {
		fail("%s result struct: %v", name, err)
	}
	var result any
	for {
		_, ftype, fid, err := p.ReadFieldBegin(ctx)
		if err != nil {
			fail("%s result field: %v", name, err)
		}
		if ftype == thrift.STOP {
			break
		}
		if fid == 0 && ftype == want {
			switch want {
			case thrift.STRING:
				result, err = p.ReadString(ctx)
			case thrift.I32:
				result, err = p.ReadI32(ctx)
			}
			if err != nil {
				fail("%s result value: %v", name, err)
			}
		} else if err := p.Skip(ctx, ftype); err != nil {
			fail("%s skip: %v", name, err)
		}
		if err := p.ReadFieldEnd(ctx); err != nil {
			fail("%s field end: %v", name, err)
		}
	}
	_ = p.ReadStructEnd(ctx)
	_ = p.ReadMessageEnd(ctx)
	return result
}

func main() {
	addr := flag.String("addr", "127.0.0.1:9090", "thrift address")
	flag.Parse()
	trans, p := dial(*addr)
	defer trans.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pong := call(ctx, trans, p, "ping", 1, func() error {
		if err := p.WriteFieldBegin(ctx, "s", thrift.STRING, 1); err != nil {
			return err
		}
		if err := p.WriteString(ctx, "go"); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.STRING)
	expect(pong == "pong:go", "ping returns pong:go")

	sum := call(ctx, trans, p, "add", 2, func() error {
		if err := p.WriteFieldBegin(ctx, "a", thrift.I32, 1); err != nil {
			return err
		}
		if err := p.WriteI32(ctx, 20); err != nil {
			return err
		}
		if err := p.WriteFieldEnd(ctx); err != nil {
			return err
		}
		if err := p.WriteFieldBegin(ctx, "b", thrift.I32, 2); err != nil {
			return err
		}
		if err := p.WriteI32(ctx, 22); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.I32)
	expect(sum == int32(42), "add returns 42")

	fmt.Println("apache thrift client interop OK")
}
