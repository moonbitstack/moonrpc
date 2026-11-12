#!/usr/bin/env bash
# The tRPC-for-TypeScript protocol against the implementation that owns it: `@trpc/server` and
# `@trpc/client`, at a pinned version, on the other side of every pairing. `trpcio` is the
# TypeScript protocol (JSON over HTTP with tRPC's batching envelope), not the `trpc.group`
# binary protocol that `trpc_interop.sh` covers, so the peer here is JavaScript rather than Go.
#
#   scripts/interop/trpcio_interop.sh <path-to-trpciod>
#
# The three pairings are the ones that make a pass mean agreement rather than self-consistency:
# their client's bytes reach this server, this client's bytes reach their server, and this stack
# against itself. `client.mjs` drives the real `httpLink` and `httpBatchLink`, so the batch
# envelope is checked in the order it was asked for.
set -euo pipefail

TRPCIOD="${1:?the trpciod binary}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PEERS="$ROOT/scripts/interop/trpcio_peers"

# A connection, not a call: this only waits for the listener, so a server that answers nothing
# yet still counts as up and the pairing beneath it decides what that means.
wait_for() {
  local port="$1"
  local log="$2"
  for _ in $(seq 1 40); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  echo "the peer on 127.0.0.1:$port never accepted a connection; it said:" >&2
  cat "$log" >&2 || true
  return 1
}

start_trpciod() {
  local port="$1"
  echo "starting $TRPCIOD on port $port" >&2
  "$TRPCIOD" "$port" >"/tmp/trpciod-$port.log" 2>&1 &
  echo $!
}

echo "== this stack's server, a TypeScript client =="
TRPCIOD_PID=$(start_trpciod 12201)
trap 'kill $TRPCIOD_PID 2>/dev/null || true' EXIT
wait_for 12201 "/tmp/trpciod-12201.log"
node "$PEERS/client.mjs" http://127.0.0.1:12201/trpc
kill $TRPCIOD_PID 2>/dev/null || true
wait $TRPCIOD_PID 2>/dev/null || true
trap - EXIT

echo "== a TypeScript server, this stack's client =="
node "$PEERS/server.mjs" 12202 >/tmp/trpcio-peer-12202.log 2>&1 &
PEER_PID=$!
trap 'kill $PEER_PID 2>/dev/null || true' EXIT
wait_for 12202 "/tmp/trpcio-peer-12202.log"
"$TRPCIOD" check 12202 127.0.0.1 | tee /tmp/trpcio-check-12202.txt
grep -q 'trpciod check: ok' /tmp/trpcio-check-12202.txt
kill $PEER_PID 2>/dev/null || true
wait $PEER_PID 2>/dev/null || true
trap - EXIT

echo "== this stack against itself, for the third pairing =="
TRPCIOD_PID=$(start_trpciod 12203)
trap 'kill $TRPCIOD_PID 2>/dev/null || true' EXIT
wait_for 12203 "/tmp/trpciod-12203.log"
"$TRPCIOD" check 12203 127.0.0.1 | tee /tmp/trpcio-check-12203.txt
grep -q 'trpciod check: ok' /tmp/trpcio-check-12203.txt
kill $TRPCIOD_PID 2>/dev/null || true
wait $TRPCIOD_PID 2>/dev/null || true
trap - EXIT

echo "tRPC-for-TypeScript interop OK"
