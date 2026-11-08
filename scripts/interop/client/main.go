// A grpc-go client that calls the moonrpc greeter: all four cardinalities, an
// interceptor chain, gzip, and plaintext or TLS. It also carries the things a call has
// beside its messages — `x-test-*` metadata the server echoes back, a deadline the
// server reports, a rich error detail, and a message large enough to need a window
// update — and exits non-zero on any mismatch, so a CI job fails on a regression.
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	greetpb "moonbitstack/moonrpc-interop/greetpb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/encoding/gzip"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/wrapperspb"
)

var (
	addr     = flag.String("addr", "127.0.0.1:12000", "greeter address")
	ca       = flag.String("ca", "", "CA bundle for TLS; empty means plaintext")
	compress = flag.Bool("gzip", false, "compress requests with gzip")
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

func logUnary(ctx context.Context, method string, req, reply any, cc *grpc.ClientConn, inv grpc.UnaryInvoker, opts ...grpc.CallOption) error {
	fmt.Printf("unary  %s\n", method)
	return inv(ctx, method, req, reply, cc, opts...)
}

func logStream(ctx context.Context, desc *grpc.StreamDesc, cc *grpc.ClientConn, method string, streamer grpc.Streamer, opts ...grpc.CallOption) (grpc.ClientStream, error) {
	fmt.Printf("stream %s\n", method)
	return streamer(ctx, desc, cc, method, opts...)
}

func dial() *grpc.ClientConn {
	var opts []grpc.DialOption
	if *ca != "" {
		pem, err := os.ReadFile(*ca)
		if err != nil {
			fail("read CA: %v", err)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			fail("the CA bundle has no certificate")
		}
		opts = append(opts, grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
			RootCAs:    pool,
			ServerName: "localhost",
		})))
	} else {
		opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}
	opts = append(opts, grpc.WithUnaryInterceptor(logUnary), grpc.WithStreamInterceptor(logStream))
	if *compress {
		opts = append(opts, grpc.WithDefaultCallOptions(grpc.UseCompressor(gzip.Name)))
	}
	conn, err := grpc.NewClient(*addr, opts...)
	if err != nil {
		fail("dial: %v", err)
	}
	return conn
}

func main() {
	flag.Parse()
	conn := dial()
	defer conn.Close()
	client := greetpb.NewGreeterClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// Metadata is the half of a call that carries no message: if the server never saw
	// `x-test-*`, or dropped the value, its echo comes back empty.
	tagged := metadata.AppendToOutgoingContext(ctx, "x-test-a", "1", "x-test-b", "2")
	var headers, trailers metadata.MD
	reply, err := client.SayHello(tagged, &greetpb.HelloRequest{
		Name:   "world",
		Mood:   greetpb.Mood_MOOD_GLAD,
		Extras: map[string]int64{"a": 2, "b": 40},
	}, grpc.Header(&headers), grpc.Trailer(&trailers))
	if err != nil {
		fail("SayHello: %v", err)
	}
	expect(reply.GetMessage() == "Hello, world", "SayHello message")
	expect(reply.GetMood() == greetpb.Mood_MOOD_GLAD, "SayHello mood")
	expect(reply.GetTotal() == 42, "SayHello total")
	expect(strings.Join(reply.GetEchoHeaders(), ",") == "x-test-a=1,x-test-b=2", "SayHello echoes x-test-* metadata")
	// The deadline this call was given is 20s; what the server saw must be a live remainder
	// of it, not a missing header and not a stale one.
	expect(reply.GetDeadlineMs() > 0 && reply.GetDeadlineMs() <= 20000,
		fmt.Sprintf("SayHello saw a deadline of %d ms", reply.GetDeadlineMs()))

	_, err = client.SayHello(ctx, &greetpb.HelloRequest{})
	st, ok := status.FromError(err)
	expect(ok && st.Code() == codes.InvalidArgument && st.Message() == "name is required", "SayHello refuses an empty name")
	// The rich half of the failure: the `Any` the server packed into grpc-status-details-bin,
	// decoded by grpc-go's own runtime rather than by our code.
	details := st.Details()
	expect(len(details) == 1, "the refusal carries one detail")
	if len(details) == 1 {
		detail, isString := details[0].(*wrapperspb.StringValue)
		expect(isString && detail.GetValue() == "name is required", "the detail is the message the server sent")
	}

	up, err := client.CountTo(ctx, &greetpb.Upto{N: 3})
	if err != nil {
		fail("CountTo: %v", err)
	}
	var counted []int32
	for {
		n, err := up.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			fail("CountTo recv: %v", err)
		}
		counted = append(counted, n.GetValue())
	}
	expect(len(counted) == 3 && counted[0] == 1 && counted[1] == 2 && counted[2] == 3, "CountTo 1..3")

	sum, err := client.Sum(ctx)
	if err != nil {
		fail("Sum: %v", err)
	}
	for _, v := range []int32{1, 2, 39} {
		if err := sum.Send(&greetpb.Number{Value: v}); err != nil {
			fail("Sum send: %v", err)
		}
	}
	total, err := sum.CloseAndRecv()
	if err != nil {
		fail("Sum close: %v", err)
	}
	expect(total.GetValue() == 42, "Sum 1+2+39")

	echo, err := client.Echo(ctx)
	if err != nil {
		fail("Echo: %v", err)
	}
	for _, v := range []int32{1, 2} {
		if err := echo.Send(&greetpb.Number{Value: v}); err != nil {
			fail("Echo send: %v", err)
		}
	}
	if err := echo.CloseSend(); err != nil {
		fail("Echo close: %v", err)
	}
	var reversed []int32
	for {
		n, err := echo.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			fail("Echo recv: %v", err)
		}
		reversed = append(reversed, n.GetValue())
	}
	expect(len(reversed) == 2 && reversed[0] == 2 && reversed[1] == 1, "Echo reverses")

	// A message larger than one HTTP/2 frame, in both directions: the window has to be credited
	// mid-message, which a call that fits in a frame never asks for.
	batch := &greetpb.Batch{Values: make([]int32, 40000)}
	for i := range batch.Values {
		batch.Values[i] = int32(i)
	}
	echoed, err := client.BatchEcho(ctx, batch)
	if err != nil {
		fail("BatchEcho: %v", err)
	}
	expect(len(echoed.GetValues()) == len(batch.Values), "BatchEcho returns every value")
	expect(echoed.GetValues()[len(batch.Values)-1] == int32(len(batch.Values)-1), "BatchEcho returns them in order")

	fmt.Println("grpc-go client interop OK")
}
