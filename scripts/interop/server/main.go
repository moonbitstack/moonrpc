// A grpc-go server implementing the same greeter as moonrpc's `cmd/greetd`, so the
// moonrpc generated client can call it and the two answers must agree. Plaintext or
// TLS, gzip, and an interceptor chain on every call. The reply echoes the caller's
// `x-test-*` metadata and the deadline it was given, a refused name carries a rich
// error detail, and a Batch comes back whole — the four things a message-only test
// never sees.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"sort"
	"strings"
	"time"

	greetpb "moonbitstack/moonrpc-interop/greetpb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	_ "google.golang.org/grpc/encoding/gzip"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/wrapperspb"
)

var (
	addr = flag.String("addr", "127.0.0.1:12002", "listen address")
	cert = flag.String("cert", "", "TLS certificate; empty means plaintext")
	key  = flag.String("key", "", "TLS private key")
)

type server struct {
	greetpb.UnimplementedGreeterServer
}

func (s *server) SayHello(ctx context.Context, req *greetpb.HelloRequest) (*greetpb.HelloReply, error) {
	if req.GetName() == "" {
		// A rich status: the detail is the half of a failure a caller can read, and a server
		// that only sets a code leaves it with nothing to decode.
		withDetails, err := status.New(codes.InvalidArgument, "name is required").
			WithDetails(wrapperspb.String("name is required"))
		if err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
		return nil, withDetails.Err()
	}
	var total int64
	for _, v := range req.GetExtras() {
		total += v
	}
	// What the caller sent beside the message, and how much of its deadline is left: the two
	// things a request that never leaves the message path cannot check.
	var echo []string
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		for key, values := range md {
			if !strings.HasPrefix(key, "x-test-") {
				continue
			}
			for _, v := range values {
				echo = append(echo, key+"="+v)
			}
		}
	}
	sort.Strings(echo)
	deadline := int64(-1)
	if d, ok := ctx.Deadline(); ok {
		deadline = time.Until(d).Milliseconds()
	}
	return &greetpb.HelloReply{
		Message:     "Hello, " + req.GetName(),
		Mood:        req.GetMood(),
		Total:       total,
		EchoHeaders: echo,
		DeadlineMs:  deadline,
	}, nil
}

func (s *server) BatchEcho(_ context.Context, req *greetpb.Batch) (*greetpb.Batch, error) {
	return &greetpb.Batch{Values: req.GetValues()}, nil
}

func (s *server) CountTo(req *greetpb.Upto, stream greetpb.Greeter_CountToServer) error {
	for i := int32(1); i <= req.GetN(); i++ {
		if err := stream.Send(&greetpb.Number{Value: i}); err != nil {
			return err
		}
	}
	return nil
}

func (s *server) Sum(stream greetpb.Greeter_SumServer) error {
	var total int32
	for {
		m, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		total += m.GetValue()
	}
	return stream.SendAndClose(&greetpb.Number{Value: total})
}

func (s *server) Echo(stream greetpb.Greeter_EchoServer) error {
	var values []int32
	for {
		m, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		values = append(values, m.GetValue())
	}
	for i := len(values) - 1; i >= 0; i-- {
		if err := stream.Send(&greetpb.Number{Value: values[i]}); err != nil {
			return err
		}
	}
	return nil
}

func logUnary(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	fmt.Printf("call %s\n", info.FullMethod)
	return handler(ctx, req)
}

func logStream(srv any, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	fmt.Printf("call %s (stream)\n", info.FullMethod)
	return handler(srv, stream)
}

func main() {
	flag.Parse()
	var opts []grpc.ServerOption
	opts = append(opts, grpc.UnaryInterceptor(logUnary), grpc.StreamInterceptor(logStream))
	if *cert != "" {
		creds, err := credentials.NewServerTLSFromFile(*cert, *key)
		if err != nil {
			log.Fatalf("TLS: %v", err)
		}
		opts = append(opts, grpc.Creds(creds))
	}
	lis, err := net.Listen("tcp", *addr)
	if err != nil {
		log.Fatalf("listen: %v", err)
	}
	s := grpc.NewServer(opts...)
	greetpb.RegisterGreeterServer(s, &server{})
	fmt.Printf("grpc-go greeter listening on %s\n", *addr)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
