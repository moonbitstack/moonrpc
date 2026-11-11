#!/usr/bin/env bash
# moonrpc against itself: the two halves of this stack, over every transport it serves.
#
# The foreign-peer jobs (grpc-go, Apache Thrift) prove the bytes leave this implementation
# the way another one expects them. This one proves the halves agree with each other, in
# every combination a server can be configured for — and it is the only run that exercises
# a given transport on both sides at once, since the peers pick their own settings.
#
#   gRPC    plaintext / TLS      x identity / gzip
#   Thrift  framed / header      x binary / compact, header also x zlib
#
# Usage: self_test.sh <greetd-binary> <thriftd-binary>
set -euo pipefail

GREETD=${1:?the greetd binary}
THRIFTD=${2:?the thriftd binary}

work=$(mktemp -d)
server=""
cleanup() {
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; fi
  rm -rf "$work" 2>/dev/null || true
}
trap cleanup EXIT

wait_for() {
  for _ in $(seq 1 40); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; then
      exec 3>&-
      return 0
    fi
    sleep 0.5
  done
  echo "nothing listening on $1" >&2
  return 1
}

# A CA and a leaf for it, the same shape the foreign-peer jobs use: ALPN is the client's,
# the chain is what both ends verify.
make_cert() {
  local dir=$1
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout "$dir/ca-key.pem" -out "$dir/ca.pem" -days 2 -nodes \
    -subj "/CN=moonrpc self test CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout "$dir/key.pem" -out "$dir/server.csr" -nodes \
    -subj "/CN=localhost" 2>/dev/null
  printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\n' \
    > "$dir/ext.cnf"
  openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca-key.pem" \
    -CAcreateserial -out "$dir/cert.pem" -days 2 -extfile "$dir/ext.cnf" 2>/dev/null
}

make_cert "$work"

port=12400

# The gRPC pair. `greetd check` is the same probe the grpc-go server job runs, so what it
# asserts about metadata, the deadline, a rich error detail and a 160 KB message is asserted
# here too — against this stack's other half rather than grpc-go's.
for mode in plaintext tls; do
  for enc in identity gzip; do
    label="grpc/$mode/$enc"
    port=$((port + 2))
    echo "== $label: moonrpc client -> moonrpc server =="
    if [ "$mode" = tls ]; then
      "$GREETD" "$port" "$work/cert.pem" "$work/key.pem" >/dev/null 2>&1 &
    else
      "$GREETD" "$port" >/dev/null 2>&1 &
    fi
    server=$!
    wait_for "$port"

    args=("$port")
    if [ "$mode" = tls ]; then args+=("$work/ca.pem"); fi
    if [ "$enc" = gzip ]; then args+=("gzip"); fi
    "$GREETD" check "${args[@]}" | tee "$work/out.txt"

    grep -q 'client and channel agree' "$work/out.txt"
    grep -q 'SayHello echo  x-test-a=1,x-test-b=2' "$work/out.txt"
    grep -q '^deadline [0-9]' "$work/out.txt"
    grep -q 'SayHello detail  type.googleapis.com/google.protobuf.StringValue' "$work/out.txt"
    grep -q 'BatchEcho size  40000' "$work/out.txt"

    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    server=""
  done
done

# The Thrift pair: every transport this stack serves, every protocol inside each, and the
# transform the header transport can carry. `thriftd check` sends a ONEWAY call and then asks
# what the server saw, so a stray reply frame would arrive as the answer to the wrong call.
for wire in framed buffered zlib http header header-zlib; do
  for proto in binary compact json; do
    if [ "$wire" = "header-zlib" ] && [ "$proto" = "json" ]; then continue; fi
    if [ "$wire" = "header" ] && [ "$proto" = "json" ]; then continue; fi
    label="thrift/$wire/$proto"
    port=$((port + 2))
    echo "== $label: moonrpc client -> moonrpc server =="
    "$THRIFTD" "$port" "$wire" "$proto" >/dev/null 2>&1 &
    server=$!
    wait_for "$port"

    "$THRIFTD" check "$port" "$wire" "$proto" | tee "$work/out.txt"

    grep -q 'ping  pong:moonrpc' "$work/out.txt"
    grep -q 'add   42' "$work/out.txt"
    grep -q 'double 3' "$work/out.txt"
    grep -q 'boom:no' "$work/out.txt"
    grep -q 'note  moonrpc' "$work/out.txt"

    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    server=""
  done
done

echo "moonrpc self interop passed: gRPC plaintext/TLS x identity/gzip; Thrift framed/buffered/zlib/http/header/header-zlib x binary/compact/json"
