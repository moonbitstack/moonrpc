#!/usr/bin/env bash
# Four pairings, one per direction and peer: this stack's server answering tRPC-Go and
# tRPC-Python clients, and this stack's client calling their servers. Each peer encodes and
# decodes with its own implementation's codec, so a pass says the two agree on the wire. Every
# run covers all four cardinalities — unary, server streaming, client streaming and
# bidirectional — because a frame shape that only one side implements is the failure this job
# exists to catch.
#
#   scripts/interop/trpc_interop.sh <path-to-trpcd> <path-to-go-peer> <python>
#
# The third argument is the interpreter that has tRPC-Python installed; CI passes `python3`
# after `pip install trpc-python`.
set -euo pipefail

TRPCD="${1:?the trpcd binary}"
GO_PEER="${2:?the trpc-go peer binary}"
PYTHON="${3:-python3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PEER="$ROOT/scripts/interop/trpcpeer.py"

# A connection, not a call: this only waits for the listener, so a server that answers
# nothing yet still counts as up and the pairing beneath it decides what that means.
wait_for() {
  local port="$1"
  for _ in $(seq 1 40); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  echo "the server on 127.0.0.1:$port never accepted a connection; it said:" >&2
  cat "/tmp/trpcd-$port.log" >&2 || true
  return 1
}

start_trpcd() {
  local port="$1"
  echo "starting $TRPCD on port $port" >&2
  "$TRPCD" "$port" >"/tmp/trpcd-$port.log" 2>&1 &
  echo $!
}

echo "== this stack's server, a tRPC-Go client =="
TRPCD_PID=$(start_trpcd 12101)
trap 'kill $TRPCD_PID 2>/dev/null || true' EXIT
wait_for 12101
"$GO_PEER" -mode client -addr 127.0.0.1:12101
kill $TRPCD_PID 2>/dev/null || true
wait $TRPCD_PID 2>/dev/null || true
trap - EXIT

echo "== this stack's server, a tRPC-Python client =="
TRPCD_PID=$(start_trpcd 12102)
trap 'kill $TRPCD_PID 2>/dev/null || true' EXIT
wait_for 12102
"$PYTHON" "$PEER" --mode client --addr 127.0.0.1:12102
kill $TRPCD_PID 2>/dev/null || true
wait $TRPCD_PID 2>/dev/null || true
trap - EXIT

echo "== a tRPC-Go server, this stack's client =="
"$GO_PEER" -mode server -addr 127.0.0.1:12103 >/tmp/trpcgo-12103.log 2>&1 &
GO_PID=$!
trap 'kill $GO_PID 2>/dev/null || true' EXIT
sleep 1
"$TRPCD" check 12103 127.0.0.1 | tee /tmp/trpc-check-12103.txt
grep -q 'client and server agree' /tmp/trpc-check-12103.txt
kill $GO_PID 2>/dev/null || true
wait $GO_PID 2>/dev/null || true
trap - EXIT

echo "== a tRPC-Python server, this stack's client =="
"$PYTHON" "$PEER" --mode server --addr 127.0.0.1:12104 >/tmp/trpcpy-12104.log 2>&1 &
PY_PID=$!
trap 'kill $PY_PID 2>/dev/null || true' EXIT
sleep 1
"$TRPCD" check 12104 127.0.0.1 | tee /tmp/trpc-check-12104.txt
grep -q 'client and server agree' /tmp/trpc-check-12104.txt
kill $PY_PID 2>/dev/null || true
wait $PY_PID 2>/dev/null || true
trap - EXIT

echo "== this stack against itself, for the fifth pairing =="
TRPCD_PID=$(start_trpcd 12105)
trap 'kill $TRPCD_PID 2>/dev/null || true' EXIT
wait_for 12105
"$TRPCD" check 12105 127.0.0.1 | tee /tmp/trpc-check-12105.txt
grep -q 'client and server agree' /tmp/trpc-check-12105.txt
kill $TRPCD_PID 2>/dev/null || true
wait $TRPCD_PID 2>/dev/null || true
trap - EXIT

echo "tRPC interop OK"
