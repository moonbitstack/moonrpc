#!/usr/bin/env bash
# Apache Thrift's cross test against this stack, in both directions, over every transport and
# every protocol the two have in common.
#
# Stage 1: an Apache Thrift client (`test/go/src/bin/testclient`) calls `ThriftTest` as this
#          repository serves it.
# Stage 2: this repository's client calls the Apache Thrift server (`testserver`) and checks
#          every answer the reference client checks.
#
# Usage: thrift_cross_test.sh <athrift-checkout> <thriftcrosstest-binary>
#
# The checkout must already hold the generated Go bindings and both built binaries; the CI job
# does that, and so does `scripts/interop/build_thrift_peers.sh`.
#
# Apache's own cross test drives four transports (`-transport buffered|framed|http|zlib`) and
# three protocols (`-protocol binary|compact|json`), and the twelve pairings are run here in
# both directions. The header transport is not among them: Apache's test binaries reach it
# through `-protocol header`, which this repository covers in `scripts/interop/thriftclient`
# and `thriftserver` instead — the same library, called directly.
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
for transport in framed buffered zlib http; do
  for protocol in binary compact json; do
    port=$((port + 2))

    echo "== $transport/$protocol: Apache Thrift client -> this server =="
    "$MOON" "$port" "$transport" "$protocol" &
    server=$!
    trap 'stop "$server"' EXIT
    wait_for "$port"
    "$PEERS/testclient$SUFFIX" -host 127.0.0.1 -port "$port" \
      -transport "$transport" -protocol "$protocol"
    stop "$server"
    trap - EXIT

    echo "== $transport/$protocol: this client -> Apache Thrift server =="
    "$PEERS/testserver$SUFFIX" -host 127.0.0.1 -port "$((port + 1))" \
      -transport "$transport" -protocol "$protocol" \
      > "${TMPDIR:-/tmp}/athrift-$transport-$protocol-server.log" 2>&1 &
    server=$!
    trap 'stop "$server"' EXIT
    wait_for "$((port + 1))"
    "$MOON" check "$((port + 1))" "$transport" "$protocol" \
      | grep -q "cross test passed ($protocol)"
    stop "$server"
    trap - EXIT
  done
done

echo "Apache Thrift cross test passed: four transports and three protocols, both directions"
