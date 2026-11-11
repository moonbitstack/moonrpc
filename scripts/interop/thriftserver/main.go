// An Apache Thrift server implementing the same methods as moonrpc's `thriftd`, so the
// moonrpc client can call it: one of Apache's three protocols, over one of its four
// transports, with a ONEWAY method that answers nothing.
package main

import (
	"compress/zlib"
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/apache/thrift/lib/go/thrift"
)

// lastNote is what the last ONEWAY call carried. A oneway method has no reply to put it in, so
// the only way for a caller to see that it arrived is to ask a later call.
var lastNote struct {
	sync.Mutex
	text string
}

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
		case thrift.DOUBLE:
			v, err := in.ReadDouble(ctx)
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

	// A ONEWAY call is answered with nothing at all: not an empty result, not a reply frame.
	// Writing one would leave a stray frame in front of the reply to the caller's next call.
	if mtype == thrift.ONEWAY {
		if name == "note" {
			lastNote.Lock()
			lastNote.text, _ = values[1].(string)
			lastNote.Unlock()
		}
		return true, nil
	}

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
	case "double":
		if err := out.WriteFieldBegin(ctx, "success", thrift.DOUBLE, 0); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteDouble(ctx, 2*values[1].(float64)); err != nil {
			return false, thrift.WrapTException(err)
		}
	case "add":
		if err := out.WriteFieldBegin(ctx, "success", thrift.I32, 0); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteI32(ctx, values[1].(int32)+values[2].(int32)); err != nil {
			return false, thrift.WrapTException(err)
		}
	case "last_note":
		lastNote.Lock()
		seen := lastNote.text
		lastNote.Unlock()
		if err := out.WriteFieldBegin(ctx, "success", thrift.STRING, 0); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteString(ctx, seen); err != nil {
			return false, thrift.WrapTException(err)
		}
	case "fail":
		// A value in field 0, or the exception in field 1, as a `throws` clause numbers it.
		text := values[1].(string)
		if text == "ok" {
			if err := out.WriteFieldBegin(ctx, "success", thrift.STRING, 0); err != nil {
				return false, thrift.WrapTException(err)
			}
			if err := out.WriteString(ctx, "fine:"+text); err != nil {
				return false, thrift.WrapTException(err)
			}
			break
		}
		if err := out.WriteFieldBegin(ctx, "boom", thrift.STRUCT, 1); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteStructBegin(ctx, "Boom"); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteFieldBegin(ctx, "message", thrift.STRING, 1); err != nil {
			return false, thrift.WrapTException(err)
		}
		if err := out.WriteString(ctx, "boom:"+text); err != nil {
			return false, thrift.WrapTException(err)
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
	protocol := flag.String("protocol", "binary", "binary, compact or json")
	transport := flag.String("transport", "framed", "framed, buffered, zlib, http, or the header transport")
	zlibTransform := flag.Bool("zlib", false, "header transport only: compress every frame with the zlib transform")
	compact := flag.Bool("compact", false, "compatibility: same as -protocol compact")
	flag.Parse()
	if *compact {
		*protocol = "compact"
	}
	conf := &thrift.TConfiguration{}

	// The http transport is not a TTransport on the server side: Apache brings a handler that
	// speaks HTTP for it, one POST per call, which is the mirror of its THttpClient.
	if *transport == "http" {
		var inFactory, outFactory thrift.TProtocolFactory
		switch *protocol {
		case "compact":
			inFactory = thrift.NewTCompactProtocolFactoryConf(conf)
			outFactory = thrift.NewTCompactProtocolFactoryConf(conf)
		case "json":
			inFactory = thrift.NewTJSONProtocolFactory()
			outFactory = thrift.NewTJSONProtocolFactory()
		case "binary":
			inFactory = thrift.NewTBinaryProtocolFactoryConf(conf)
			outFactory = thrift.NewTBinaryProtocolFactoryConf(conf)
		default:
			log.Fatalf("protocol %q is not one this probe speaks: binary, compact or json", *protocol)
		}
		handler := thrift.NewThriftHandlerFunc(processor{}, inFactory, outFactory)
		mux := http.NewServeMux()
		mux.HandleFunc("/", handler)
		fmt.Printf("apache thrift greeter listening on %s (http, %s)\n", *addr, *protocol)
		if err := http.ListenAndServe(*addr, mux); err != nil {
			log.Fatalf("serve: %v", err)
		}
		return
	}

	socket, err := thrift.NewTServerSocket(*addr)
	if err != nil {
		log.Fatalf("socket: %v", err)
	}
	var transportFactory thrift.TTransportFactory
	var protocolFactory thrift.TProtocolFactory
	if *transport == "header" {
		// The header transport carries the inner protocol's name in each frame, so the factory
		// below is the pairing Apache's own tests use: the transport factory frames, the
		// protocol factory decides what goes inside.
		transportFactory = thrift.NewTHeaderTransportFactoryConf(thrift.NewTTransportFactory(), conf)
		if *protocol == "compact" {
			conf.THeaderProtocolID = thrift.THeaderProtocolIDPtrMust(thrift.THeaderProtocolCompact)
		} else {
			conf.THeaderProtocolID = thrift.THeaderProtocolIDPtrMust(thrift.THeaderProtocolBinary)
		}
		protocolFactory = thrift.NewTHeaderProtocolFactoryConf(conf)
	} else {
		switch *transport {
		case "framed":
			transportFactory = thrift.NewTFramedTransportFactoryConf(thrift.NewTTransportFactory(), conf)
		case "buffered":
			transportFactory = thrift.NewTBufferedTransportFactory(8192)
		case "zlib":
			transportFactory = thrift.NewTZlibTransportFactoryWithFactory(zlib.BestCompression, thrift.NewTTransportFactory())
		default:
			log.Fatalf("transport %q is not one this probe speaks: framed, buffered, zlib, http or header", *transport)
		}
		switch *protocol {
		case "compact":
			protocolFactory = thrift.NewTCompactProtocolFactoryConf(conf)
		case "json":
			protocolFactory = thrift.NewTJSONProtocolFactory()
		case "binary":
			protocolFactory = thrift.NewTBinaryProtocolFactoryConf(conf)
		default:
			log.Fatalf("protocol %q is not one this probe speaks: binary, compact or json", *protocol)
		}
	}
	_ = zlibTransform
	server := thrift.NewTSimpleServer4(processor{}, socket, transportFactory, protocolFactory)
	fmt.Printf("apache thrift greeter listening on %s (%s, %s)\n", *addr, *transport, *protocol)
	if err := server.Serve(); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
