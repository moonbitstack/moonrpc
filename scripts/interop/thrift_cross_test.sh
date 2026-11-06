#!/usr/bin/env bash
# Apache Thrift's cross test against this stack, in both directions and both protocols.
#
# Stage 1: an Apache Thrift client (`test/go/src/bin/testclient`) calls `ThriftTest` as
#          this repository serves it.
# Stage 2: this repository's client calls the Apache Thrift server (`testserver`) and
#          checks every answer the reference client checks.
#
# Usage: thrift_cross_test.sh <athrift-checkout> <thriftcrosstest-binary>
#
# The checkout must already hold the generated Go bindings and both built binaries; the
# CI job does that, and so does `scripts/interop/build_thrift_peers.sh`.
set -euo pipefail

REF=${1:?the Apache Thrift checkout that holds test/go/bin}
MOON=${2:?the thriftcrosstest binary}
PEERS="$REF/test/go/bin"
SUFFIX=""
[ -x "$PEERS/testclient" ] || SUFFIX=".exe"

wait_for() {
  for _ in $(seq 1 30); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; then
      exec 3>&-
      return 0
    fi
    sleep 1
  done
  echo "nothing listening on $1" >&2
  return 1
}

stop() {
  kill "$1" 2>/dev/null || true
  wait "$1" 2>/dev/null || true
}

port=9300
for protocol in binary compact; do
  arg=""
  if [ "$protocol" = compact ]; then arg=compact; fi
  port=$((port + 2))

  echo "== $protocol: Apache Thrift client -> this server =="
  "$MOON" "$port" $arg &
  server=$!
  trap 'stop "$server"' EXIT
  wait_for "$port"
  "$PEERS/testclient$SUFFIX" -host 127.0.0.1 -port "$port" -transport framed -protocol "$protocol"
  stop "$server"
  trap - EXIT

  echo "== $protocol: this client -> Apache Thrift server =="
  "$PEERS/testserver$SUFFIX" -host 127.0.0.1 -port "$((port + 1))" -transport framed -protocol "$protocol" \
    > "${TMPDIR:-/tmp}/athrift-$protocol-server.log" 2>&1 &
  server=$!
  trap 'stop "$server"' EXIT
  wait_for "$((port + 1))"
  "$MOON" check "$((port + 1))" $arg | grep -q "cross test passed ($protocol)"
  stop "$server"
  trap - EXIT
done

echo "Apache Thrift cross test passed: both directions, both protocols"
