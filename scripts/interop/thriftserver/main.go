// An Apache Thrift server implementing the same two methods as moonrpc's `thriftd`,
// so the moonrpc client can call it. TBinaryProtocol over TFramedTransport.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"

	"github.com/apache/thrift/lib/go/thrift"
)

type processor struct{}

func (processor) Process(ctx context.Context, in, out thrift.TProtocol) (bool, thrift.TException) {
	name, mtype, seqid, err := in.ReadMessageBegin(ctx)
	if err != nil {
		return false, thrift.WrapTException(err)
	}
	if mtype != thrift.CALL && mtype != thrift.ONEWAY {
		return false, thrift.NewTProtocolExceptionWithType(thrift.INVALID_MESSAGE_TYPE_EXCEPTION, fmt.Errorf("bad message type %d", mtype))
	}
	if _, err := in.ReadStructBegin(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	values := map[int16]any{}
	for {
		_, ftype, fid, err := in.ReadFieldBegin(ctx)
		if err != nil {
			return false, thrift.WrapTException(err)
		}
		if ftype == thrift.STOP {
			break
		}
		switch ftype {
		case thrift.STRING:
			v, err := in.ReadString(ctx)
			if err != nil {
				return false, thrift.WrapTException(err)
			}
			values[fid] = v
		case thrift.I32:
			v, err := in.ReadI32(ctx)
			if err != nil {
				return false, thrift.WrapTException(err)
			}
			values[fid] = v
		default:
			if err := in.Skip(ctx, ftype); err != nil {
				return false, thrift.WrapTException(err)
			}
		}
		if err := in.ReadFieldEnd(ctx); err != nil {
			return false, thrift.WrapTException(err)
		}
	}
	_ = in.ReadStructEnd(ctx)
	_ = in.ReadMessageEnd(ctx)

	if err := out.WriteMessageBegin(ctx, name, thrift.REPLY, seqid); err != nil {
		return false, thrift.WrapTException(err)
	}
	if err := out.WriteStructBegin(ctx, name+"_result"); err != nil {
		return false, thrift.WrapTException(err)
	}
	switch name {
	case "ping":
		if err := out.WriteFieldBegin(ctx, "success", thrift.STRING, 0); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteString(ctx, "pong:"+values[1].(string)); err != nil {
			return false, thrift.WrapTException(err)
		}
	case "add":
		if err := out.WriteFieldBegin(ctx, "success", thrift.I32, 0); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteI32(ctx, values[1].(int32)+values[2].(int32)); err != nil {
			return false, thrift.WrapTException(err)
		}
	default:
		return false, thrift.NewTApplicationException(thrift.UNKNOWN_METHOD, "unknown method: "+name)
	}
	if err := out.WriteFieldEnd(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	if err := out.WriteFieldStop(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	if err := out.WriteStructEnd(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	if err := out.WriteMessageEnd(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	if err := out.Flush(ctx); err != nil {
		return false, thrift.WrapTException(err)
	}
	return true, nil
}

func (processor) ProcessorMap() map[string]thrift.TProcessorFunction { return nil }

func (processor) AddToProcessorMap(string, thrift.TProcessorFunction) {}

func main() {
	addr := flag.String("addr", "127.0.0.1:9091", "listen address")
	flag.Parse()
	socket, err := thrift.NewTServerSocket(*addr)
	if err != nil {
		log.Fatalf("socket: %v", err)
	}
	transportFactory := thrift.NewTFramedTransportFactoryConf(thrift.NewTTransportFactory(), &thrift.TConfiguration{})
	protocolFactory := thrift.NewTBinaryProtocolFactoryConf(&thrift.TConfiguration{})
	server := thrift.NewTSimpleServer4(processor{}, socket, transportFactory, protocolFactory)
	fmt.Printf("apache thrift greeter listening on %s\n", *addr)
	if err := server.Serve(); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
