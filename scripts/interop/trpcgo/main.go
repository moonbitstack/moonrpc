// A tRPC peer written against tRPC-Go's own protocol codec: the frames this program sends
// and accepts are the ones that library builds and reads, not a second implementation of
// the format. `-mode server` answers the two methods `cmd/trpcd` serves; `-mode client`
// calls whichever peer is at `-addr`.
//
// The messages are hand-encoded protobuf, because what is under test is the frame rather
// than the message: `SayHelloRequest{string name = 1}`, `SayHelloReply{string text = 1,
// string metadata = 2}`, `CountRequest{int32 n = 1}`, `Number{int32 value = 1}`.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"

	"trpc.group/trpc-go/trpc-go"
	"trpc.group/trpc-go/trpc-go/codec"
	trpcpb "trpc.group/trpc/trpc-protocol/pb/go/trpc"
)

const (
	sayHelloPath = "/trpc.test.Greeter/SayHello"
	countPath    = "/trpc.test.Greeter/Count"
)

// -- protobuf, by hand -------------------------------------------------------

func varint(out []byte, value uint64) []byte {
	for value >= 0x80 {
		out = append(out, byte(value)|0x80)
		value >>= 7
	}
	return append(out, byte(value))
}

func tag(out []byte, field int, wire int) []byte {
	return varint(out, uint64(field<<3|wire))
}

func stringField(out []byte, field int, value string) []byte {
	out = tag(out, field, 2)
	out = varint(out, uint64(len(value)))
	return append(out, value...)
}

func int32Field(out []byte, field int, value int32) []byte {
	out = tag(out, field, 0)
	return varint(out, uint64(uint32(value)))
}

func readVarint(data []byte, at int) (uint64, int) {
	var value uint64
	var shift uint
	for {
		if at >= len(data) {
			return value, at
		}
		b := data[at]
		at++
		value |= uint64(b&0x7f) << shift
		if b&0x80 == 0 {
			return value, at
		}
		shift += 7
	}
}

// readFields walks a message and hands each field's number and value to `visit`, which
// returns false when it has found what it wanted.
func readFields(data []byte, visit func(field int, wire int, value uint64, raw []byte) bool) {
	at := 0
	for at < len(data) {
		key, next := readVarint(data, at)
		at = next
		field, wire := int(key>>3), int(key&7)
		switch wire {
		case 0:
			value, after := readVarint(data, at)
			at = after
			if !visit(field, wire, value, nil) {
				return
			}
		case 2:
			size, after := readVarint(data, at)
			end := after + int(size)
			if end > len(data) {
				return
			}
			if !visit(field, wire, 0, data[after:end]) {
				return
			}
			at = end
		case 5:
			at += 4
		case 1:
			at += 8
		default:
			return
		}
	}
}

func decodeName(body []byte) string {
	name := ""
	readFields(body, func(field int, _ int, _ uint64, raw []byte) bool {
		if field == 1 {
			name = string(raw)
		}
		return true
	})
	return name
}

func decodeCount(body []byte) int32 {
	n := int32(0)
	readFields(body, func(field int, wire int, value uint64, _ []byte) bool {
		if field == 1 && wire == 0 {
			n = int32(value)
		}
		return true
	})
	return n
}

// -- client ------------------------------------------------------------------

// call sends one unary frame and returns the reply body, or the response's return code.
func call(conn net.Conn, framer codec.Framer, path string, body []byte) ([]byte, int32, string) {
	_, msg := codec.WithNewMessage(context.Background())
	msg.WithClientRPCName(path)
	msg.WithCalleeServiceName("trpc.test.Greeter")
	msg.WithCallerServiceName("trpc.go.client.service")
	msg.WithRequestTimeout(5 * time.Second)
	msg.WithSerializationType(0)
	msg.WithCompressType(0)
	msg.WithClientMetaData(codec.MetaData{"x-test": []byte("trpc-go")})

	frame, err := trpc.DefaultClientCodec.Encode(msg, body)
	if err != nil {
		return nil, 0, "encode: " + err.Error()
	}
	if _, err := conn.Write(frame); err != nil {
		return nil, 0, "write: " + err.Error()
	}
	reply, err := framer.ReadFrame()
	if err != nil {
		return nil, 0, "read: " + err.Error()
	}
	decoded, err := trpc.DefaultClientCodec.Decode(msg, reply)
	if err != nil {
		return nil, 0, "decode: " + err.Error()
	}
	if head, ok := msg.ClientRspHead().(*trpcpb.ResponseProtocol); ok {
		if head.Ret != 0 || head.FuncRet != 0 {
			return nil, head.Ret + head.FuncRet, string(head.ErrorMsg)
		}
	}
	return decoded, 0, ""
}

// streamCall sends INIT, one DATA and a CLOSE, and reads until the server closes.
func streamCall(conn net.Conn, framer codec.Framer, path string, body []byte) ([]string, string) {
	streamID := uint32(3)
	_, msg := codec.WithNewMessage(context.Background())
	msg.WithClientRPCName(path)
	msg.WithCalleeServiceName("trpc.test.Greeter")
	msg.WithCallerServiceName("trpc.go.client.service")
	msg.WithSerializationType(0)
	msg.WithCompressType(0)
	msg.WithStreamID(streamID)

	init := &trpcpb.TrpcStreamInitMeta{
		RequestMeta: &trpcpb.TrpcStreamInitRequestMeta{
			Caller: []byte("trpc.go.client.service"),
			Callee: []byte("trpc.test.Greeter"),
			Func:   []byte(path),
		},
		InitWindowSize: 65535,
	}
	msg.WithFrameHead(&trpc.FrameHead{
		FrameType:       uint8(trpcpb.TrpcDataFrameType_TRPC_STREAM_FRAME),
		StreamFrameType: uint8(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_INIT),
		StreamID:        streamID,
		ProtocolVersion: 1,
	})
	msg.WithStreamFrame(init)
	frame, err := trpc.DefaultClientCodec.Encode(msg, nil)
	if err != nil {
		return nil, "encode init: " + err.Error()
	}
	if _, err := conn.Write(frame); err != nil {
		return nil, "write init: " + err.Error()
	}

	msg.WithFrameHead(&trpc.FrameHead{
		FrameType:       uint8(trpcpb.TrpcDataFrameType_TRPC_STREAM_FRAME),
		StreamFrameType: uint8(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_DATA),
		StreamID:        streamID,
		ProtocolVersion: 1,
	})
	frame, err = trpc.DefaultClientCodec.Encode(msg, body)
	if err != nil {
		return nil, "encode data: " + err.Error()
	}
	if _, err := conn.Write(frame); err != nil {
		return nil, "write data: " + err.Error()
	}

	msg.WithFrameHead(&trpc.FrameHead{
		FrameType:       uint8(trpcpb.TrpcDataFrameType_TRPC_STREAM_FRAME),
		StreamFrameType: uint8(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_CLOSE),
		StreamID:        streamID,
		ProtocolVersion: 1,
	})
	msg.WithStreamFrame(&trpcpb.TrpcStreamCloseMeta{CloseType: int32(trpcpb.TrpcStreamCloseType_TRPC_STREAM_CLOSE)})
	frame, err = trpc.DefaultClientCodec.Encode(msg, nil)
	if err != nil {
		return nil, "encode close: " + err.Error()
	}
	if _, err := conn.Write(frame); err != nil {
		return nil, "write close: " + err.Error()
	}

	var values []string
	for {
		reply, err := framer.ReadFrame()
		if err != nil {
			return values, "read: " + err.Error()
		}
		head := &trpc.FrameHead{}
		head.FrameType = reply[2]
		head.StreamFrameType = reply[3]
		state := trpcpb.TrpcStreamFrameType(head.StreamFrameType)
		decoded, err := trpc.DefaultClientCodec.Decode(msg, reply)
		if err != nil {
			return values, "decode: " + err.Error()
		}
		switch state {
		case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_INIT:
			if meta, ok := msg.StreamFrame().(*trpcpb.TrpcStreamInitMeta); ok && meta.ResponseMeta != nil {
				if meta.ResponseMeta.Ret != 0 {
					return values, string(meta.ResponseMeta.ErrorMsg)
				}
			}
		case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_DATA:
			values = append(values, fmt.Sprintf("%d", decodeCount(decoded)))
		case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_CLOSE:
			if meta, ok := msg.StreamFrame().(*trpcpb.TrpcStreamCloseMeta); ok {
				if meta.Ret != 0 || meta.FuncRet != 0 {
					return values, string(meta.Msg)
				}
			}
			return values, ""
		}
	}
}

func runClient(addr string) {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "dial %s: %v\n", addr, err)
		os.Exit(1)
	}
	defer conn.Close()
	framer := trpc.DefaultFramerBuilder.New(conn)

	body := stringField(nil, 1, "world")
	reply, code, message := call(conn, framer, sayHelloPath, body)
	if code != 0 {
		fmt.Fprintf(os.Stderr, "SayHello refused: %d %s\n", code, message)
		os.Exit(1)
	}
	text, metadata := "", ""
	readFields(reply, func(field int, _ int, _ uint64, raw []byte) bool {
		switch field {
		case 1:
			text = string(raw)
		case 2:
			metadata = string(raw)
		}
		return true
	})
	fmt.Printf("SayHello  %s  x-test=%s\n", text, metadata)
	if text != "Hello, world" {
		fmt.Fprintf(os.Stderr, "SayHello answered %q\n", text)
		os.Exit(1)
	}
	if metadata != "trpc-go" {
		fmt.Fprintf(os.Stderr, "the server did not echo x-test: %q\n", metadata)
		os.Exit(1)
	}

	values, problem := streamCall(conn, framer, countPath, int32Field(nil, 1, 3))
	if problem != "" {
		fmt.Fprintf(os.Stderr, "Count: %s\n", problem)
		os.Exit(1)
	}
	fmt.Printf("Count     %v\n", values)
	if len(values) != 3 || values[0] != "1" || values[1] != "2" || values[2] != "3" {
		fmt.Fprintf(os.Stderr, "Count answered %v\n", values)
		os.Exit(1)
	}

	_, code, message = call(conn, framer, sayHelloPath, nil)
	fmt.Printf("refused   %d %s\n", code, message)
	if code == 0 || message != "name is required" {
		fmt.Fprintf(os.Stderr, "an empty name was not refused as expected\n")
		os.Exit(1)
	}
	fmt.Println("apache peer client OK")
}

// -- server ------------------------------------------------------------------

// streamState is what the peer remembers between the frames of one stream.
type streamState struct {
	path string
	body []byte
}

func frameHead(kind trpcpb.TrpcStreamFrameType, streamID uint32) *trpc.FrameHead {
	return &trpc.FrameHead{
		FrameType:       uint8(trpcpb.TrpcDataFrameType_TRPC_STREAM_FRAME),
		StreamFrameType: uint8(kind),
		StreamID:        streamID,
		ProtocolVersion: 1,
	}
}

func answerUnary(msg codec.Msg, body []byte) [][]byte {
	req, ok := msg.ServerReqHead().(*trpcpb.RequestProtocol)
	if !ok {
		return nil
	}
	rsp := &trpcpb.ResponseProtocol{
		Version:   1,
		CallType:  req.CallType,
		RequestId: req.RequestId,
	}
	msg.WithServerRspHead(rsp)
	var reply []byte
	switch string(req.Func) {
	case sayHelloPath:
		name := decodeName(body)
		if name == "" {
			rsp.Ret = 51 // TRPC_SERVER_VALIDATE_ERR
			rsp.ErrorMsg = []byte("name is required")
			break
		}
		reply = stringField(nil, 1, "Hello, "+name)
		if value, ok := req.TransInfo["x-test"]; ok {
			reply = stringField(reply, 2, string(value))
		}
	case countPath:
		rsp.Ret = 12 // TRPC_SERVER_NOFUNC_ERR: Count is a streaming method
		rsp.ErrorMsg = []byte(countPath + " is a streaming method")
	default:
		rsp.Ret = 12
		rsp.ErrorMsg = []byte("no method is registered at " + string(req.Func))
	}
	frame, err := trpc.DefaultServerCodec.Encode(msg, reply)
	if err != nil {
		fmt.Fprintf(os.Stderr, "encode: %v\n", err)
		return nil
	}
	return [][]byte{frame}
}

func answerStream(msg codec.Msg, head *trpc.FrameHead, body []byte, streams map[uint32]*streamState) [][]byte {
	kind := trpcpb.TrpcStreamFrameType(head.StreamFrameType)
	switch kind {
	case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_INIT:
		meta, ok := msg.StreamFrame().(*trpcpb.TrpcStreamInitMeta)
		if !ok {
			return nil
		}
		path := string(meta.RequestMeta.Func)
		if path == "" && meta.RequestMeta.Callee != nil {
			path = "/" + strings.ReplaceAll(string(meta.RequestMeta.Callee), ".", "/")
		}
		streams[head.StreamID] = &streamState{path: path}
		msg.WithFrameHead(frameHead(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_INIT, head.StreamID))
		msg.WithStreamFrame(&trpcpb.TrpcStreamInitMeta{
			ResponseMeta:   &trpcpb.TrpcStreamInitResponseMeta{},
			InitWindowSize: 65535,
		})
		frame, err := trpc.DefaultServerCodec.Encode(msg, nil)
		if err != nil {
			fmt.Fprintf(os.Stderr, "encode init: %v\n", err)
			return nil
		}
		return [][]byte{frame}
	case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_DATA:
		if state, ok := streams[head.StreamID]; ok {
			state.body = append(state.body, body...)
		}
		return nil
	case trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_CLOSE:
		state, ok := streams[head.StreamID]
		if !ok {
			return nil
		}
		delete(streams, head.StreamID)
		var out [][]byte
		closeMeta := &trpcpb.TrpcStreamCloseMeta{CloseType: int32(trpcpb.TrpcStreamCloseType_TRPC_STREAM_CLOSE)}
		if state.path == countPath {
			n := decodeCount(state.body)
			for i := int32(1); i <= n; i++ {
				value := int32Field(nil, 1, i)
				msg.WithFrameHead(frameHead(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_DATA, head.StreamID))
				frame, err := trpc.DefaultServerCodec.Encode(msg, value)
				if err != nil {
					return out
				}
				out = append(out, frame)
			}
		} else {
			closeMeta.Ret = 12
			closeMeta.Msg = []byte("no streaming method is registered at " + state.path)
		}
		msg.WithFrameHead(frameHead(trpcpb.TrpcStreamFrameType_TRPC_STREAM_FRAME_CLOSE, head.StreamID))
		msg.WithStreamFrame(closeMeta)
		frame, err := trpc.DefaultServerCodec.Encode(msg, nil)
		if err != nil {
			return out
		}
		return append(out, frame)
	default:
		return nil
	}
}

func main() {
	mode := flag.String("mode", "server", "server or client")
	addr := flag.String("addr", "127.0.0.1:12000", "address to listen on or dial")
	flag.Parse()
	if *mode == "client" {
		runClient(*addr)
		return
	}
	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "listen %s: %v\n", *addr, err)
		os.Exit(1)
	}
	fmt.Printf("trpc-go peer listening on %s\n", listener.Addr())
	for {
		conn, err := listener.Accept()
		if err != nil {
			break
		}
		go serveConnection(conn)
	}
}

func serveConnection(conn net.Conn) {
	defer conn.Close()
	framer := trpc.DefaultFramerBuilder.New(conn)
	streams := map[uint32]*streamState{}
	for {
		frame, err := framer.ReadFrame()
		if err != nil {
			if err != io.EOF {
				fmt.Fprintf(os.Stderr, "read: %v\n", err)
			}
			return
		}
		head := &trpc.FrameHead{
			FrameType:       frame[2],
			StreamFrameType: frame[3],
			StreamID:        uint32(frame[10])<<24 | uint32(frame[11])<<16 | uint32(frame[12])<<8 | uint32(frame[13]),
		}
		_, msg := codec.WithNewMessage(context.Background())
		msg.WithRemoteAddr(conn.RemoteAddr())
		msg.WithLocalAddr(conn.LocalAddr())
		body, err := trpc.DefaultServerCodec.Decode(msg, frame)
		if err != nil {
			fmt.Fprintf(os.Stderr, "decode: %v\n", err)
			return
		}
		var replies [][]byte
		if head.FrameType == uint8(trpcpb.TrpcDataFrameType_TRPC_STREAM_FRAME) {
			replies = answerStream(msg, head, body, streams)
		} else {
			replies = answerUnary(msg, body)
		}
		for _, reply := range replies {
			if _, err := conn.Write(reply); err != nil {
				return
			}
		}
	}
}
