// An Apache Thrift client that calls the moonrpc Thrift server: one of Apache's three
// protocols, over one of its four transports, plus a ONEWAY call — the same service `thriftd`
// serves, in every combination it claims.
package main

import (
	"compress/zlib"
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

// wire is what the probe needs from a transport: flush a written message, and close. Apache's
// header protocol is not a TTransport itself — it wraps one — so the two shapes are reduced to
// this instead of forcing one of them into a type it is not.
type wire struct {
	flush func(context.Context) error
	close func()
}

// dial opens a connection speaking `transport` and `protocol`, and turns on the header
// transport's zlib transform when asked.
//
// The four transports are Apache's own: framed, buffered, zlib (a stream over the socket) and
// http (one POST per call). The header transport is a fifth, which Apache treats as a protocol
// because it carries the inner protocol's name in each frame.
func dial(addr, transport, protocol string, zlibTransform bool) (thrift.TProtocol, wire) {
	conf := &thrift.TConfiguration{}
	protocolOf := func(t thrift.TTransport) thrift.TProtocol {
		switch protocol {
		case "compact":
			return thrift.NewTCompactProtocolConf(t, conf)
		case "json":
			return thrift.NewTJSONProtocol(t)
		default:
			return thrift.NewTBinaryProtocolConf(t, conf)
		}
	}
	// A message leaves when the protocol is flushed: the two binary protocols write straight
	// through and their flush is the transport's, while the JSON one keeps a text buffer and
	// flushes that first. Flushing the transport as well would be a second flush of a framed
	// transport that has nothing left to send, which Apache's own implementation does not
	// survive.
	pair := func(p thrift.TProtocol, close func()) (thrift.TProtocol, wire) {
		return p, wire{flush: p.Flush, close: close}
	}
	if transport == "header" {
		conf.THeaderProtocolID = thrift.THeaderProtocolIDPtrMust(thrift.THeaderProtocolBinary)
		if protocol == "compact" {
			conf.THeaderProtocolID = thrift.THeaderProtocolIDPtrMust(thrift.THeaderProtocolCompact)
		}
		socket := thrift.NewTSocketConf(addr, conf)
		if err := socket.Open(); err != nil {
			fail("open: %v", err)
		}
		header := thrift.NewTHeaderProtocolConf(socket, conf)
		if zlibTransform {
			if err := header.AddTransform(thrift.TransformZlib); err != nil {
				fail("zlib transform: %v", err)
			}
		}
		return pair(header, func() { socket.Close() })
	}
	if transport == "http" {
		http, err := thrift.NewTHttpClient("http://" + addr + "/")
		if err != nil {
			fail("http client: %v", err)
		}
		if err := http.Open(); err != nil {
			fail("open: %v", err)
		}
		return pair(protocolOf(http), func() { http.Close() })
	}
	var trans thrift.TTransport
	switch transport {
	case "framed":
		trans = thrift.NewTFramedTransportConf(thrift.NewTSocketConf(addr, conf), conf)
	case "buffered":
		trans = thrift.NewTBufferedTransport(thrift.NewTSocketConf(addr, conf), 8192)
	case "zlib":
		compressed, err := thrift.NewTZlibTransport(thrift.NewTSocketConf(addr, conf), zlib.BestCompression)
		if err != nil {
			fail("zlib transport: %v", err)
		}
		trans = compressed
	default:
		fail("transport %q is not one this probe speaks: framed, buffered, zlib, http or header", transport)
	}
	if err := trans.Open(); err != nil {
		fail("open: %v", err)
	}
	return pair(protocolOf(trans), func() { trans.Close() })
}

func call(ctx context.Context, w wire, p thrift.TProtocol, name string, seq int32, write func() error, want thrift.TType) any {
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
	if err := w.flush(ctx); err != nil {
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
			case thrift.DOUBLE:
				result, err = p.ReadDouble(ctx)
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

// callException sends the `fail` method and reads its result struct, which carries the
// exception in field 1 — the field a `throws` clause numbers — instead of a value.
func callException(ctx context.Context, w wire, p thrift.TProtocol, name string, seq int32, text string) string {
	if err := p.WriteMessageBegin(ctx, name, thrift.CALL, seq); err != nil {
		fail("%s begin: %v", name, err)
	}
	if err := p.WriteStructBegin(ctx, name+"_args"); err != nil {
		fail("%s struct: %v", name, err)
	}
	if err := p.WriteFieldBegin(ctx, "text", thrift.STRING, 1); err != nil {
		fail("%s args: %v", name, err)
	}
	if err := p.WriteString(ctx, text); err != nil {
		fail("%s args: %v", name, err)
	}
	if err := p.WriteFieldEnd(ctx); err != nil {
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
	if err := w.flush(ctx); err != nil {
		fail("%s flush: %v", name, err)
	}
	if _, mtype, _, err := p.ReadMessageBegin(ctx); err != nil {
		fail("%s reply begin: %v", name, err)
	} else if mtype != thrift.REPLY {
		fail("%s: message type %d, not a reply", name, mtype)
	}
	if _, err := p.ReadStructBegin(ctx); err != nil {
		fail("%s result struct: %v", name, err)
	}
	message := ""
	found := false
	for {
		_, ftype, fid, err := p.ReadFieldBegin(ctx)
		if err != nil {
			fail("%s result field: %v", name, err)
		}
		if ftype == thrift.STOP {
			break
		}
		if fid == 1 && ftype == thrift.STRUCT {
			found = true
			if _, err := p.ReadStructBegin(ctx); err != nil {
				fail("%s exception struct: %v", name, err)
			}
			for {
				_, itype, iid, err := p.ReadFieldBegin(ctx)
				if err != nil {
					fail("%s exception field: %v", name, err)
				}
				if itype == thrift.STOP {
					break
				}
				if iid == 1 && itype == thrift.STRING {
					v, err := p.ReadString(ctx)
					if err != nil {
						fail("%s exception message: %v", name, err)
					}
					message = v
				} else if err := p.Skip(ctx, itype); err != nil {
					fail("%s skip: %v", name, err)
				}
				if err := p.ReadFieldEnd(ctx); err != nil {
					fail("%s field end: %v", name, err)
				}
			}
			if err := p.ReadStructEnd(ctx); err != nil {
				fail("%s exception end: %v", name, err)
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
	if !found {
		fail("%s: the reply carried no exception in field 1", name)
	}
	return message
}

func main() {
	addr := flag.String("addr", "127.0.0.1:9090", "thrift address")
	protocol := flag.String("protocol", "binary", "binary, compact or json")
	transport := flag.String("transport", "framed", "framed, buffered, zlib, http, or the header transport")
	zlib := flag.Bool("zlib", false, "header transport only: compress every frame with the zlib transform")
	compact := flag.Bool("compact", false, "compatibility: same as -protocol compact")
	flag.Parse()
	if *compact {
		*protocol = "compact"
	}
	p, w := dial(*addr, *transport, *protocol, *zlib)
	defer w.close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pong := call(ctx, w, p, "ping", 1, func() error {
		if err := p.WriteFieldBegin(ctx, "s", thrift.STRING, 1); err != nil {
			return err
		}
		if err := p.WriteString(ctx, "go"); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.STRING)
	expect(pong == "pong:go", "ping returns pong:go")

	sum := call(ctx, w, p, "add", 2, func() error {
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

	scaled := call(ctx, w, p, "double", 3, func() error {
		if err := p.WriteFieldBegin(ctx, "x", thrift.DOUBLE, 1); err != nil {
			return err
		}
		if err := p.WriteDouble(ctx, 1.5); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.DOUBLE)
	expect(scaled == float64(3), "double returns 3")

	fine := call(ctx, w, p, "fail", 4, func() error {
		if err := p.WriteFieldBegin(ctx, "text", thrift.STRING, 1); err != nil {
			return err
		}
		if err := p.WriteString(ctx, "ok"); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.STRING)
	expect(fine == "fine:ok", "a method that can throw still answers a value in field 0")

	boom := callException(ctx, w, p, "fail", 5, "no")
	expect(boom == "boom:no", "an exception arrives in field 1")

	// A ONEWAY call answers nothing at all, so the next thing on the wire is the reply to the
	// call that follows. A server that answered the oneway would put a stray frame here.
	if err := p.WriteMessageBegin(ctx, "note", thrift.ONEWAY, 6); err != nil {
		fail("note begin: %v", err)
	}
	if err := p.WriteStructBegin(ctx, "note_args"); err != nil {
		fail("note struct: %v", err)
	}
	if err := p.WriteFieldBegin(ctx, "text", thrift.STRING, 1); err != nil {
		fail("note field: %v", err)
	}
	if err := p.WriteString(ctx, "go"); err != nil {
		fail("note text: %v", err)
	}
	_ = p.WriteFieldEnd(ctx)
	_ = p.WriteFieldStop(ctx)
	_ = p.WriteStructEnd(ctx)
	_ = p.WriteMessageEnd(ctx)
	if err := w.flush(ctx); err != nil {
		fail("note flush: %v", err)
	}
	seen := call(ctx, w, p, "last_note", 7, func() error {
		if err := p.WriteFieldBegin(ctx, "text", thrift.STRING, 1); err != nil {
			return err
		}
		if err := p.WriteString(ctx, ""); err != nil {
			return err
		}
		return p.WriteFieldEnd(ctx)
	}, thrift.STRING)
	expect(seen == "go", "a oneway call arrives without a reply in front of the next one")

	fmt.Println("apache thrift client interop OK")
}
