// A grpc-go server implementing the same greeter as moonrpc's `cmd/greetd`, so the
// moonrpc generated client can call it and the two answers must agree. Plaintext or
// TLS, gzip, and an interceptor chain on every call.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"

	greetpb "moonbitstack/moonrpc-interop/greetpb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	_ "google.golang.org/grpc/encoding/gzip"
	"google.golang.org/grpc/status"
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
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	var total int64
	for _, v := range req.GetExtras() {
		total += v
	}
	return &greetpb.HelloReply{
		Message: "Hello, " + req.GetName(),
		Mood:    req.GetMood(),
		Total:   total,
	}, nil
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
