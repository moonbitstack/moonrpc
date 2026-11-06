#!/usr/bin/env bash
# Build Apache Thrift's cross-test peers: the reference client and server that
# `thrift_cross_test.sh` runs against this stack.
#
# Pinned to the release the Thrift compiler on the runner generates for (0.22). Apache's
# own Go build drops the one `CrazyNesting` field its generator cannot express; the same
# line is dropped here, so the bindings compiled are the ones that build brings up.
#
# Usage: build_thrift_peers.sh <destination-directory>
set -euo pipefail

TAG=v0.22.0
DEST=${1:?a directory to build the Apache Thrift checkout in}

rm -rf "$DEST"
git clone --depth 1 --branch "$TAG" --filter=blob:none --sparse \
  https://github.com/apache/thrift.git "$DEST"
cd "$DEST"
git sparse-checkout set --no-cone '/test/go' '/test/ThriftTest.thrift' \
  '/lib/go/thrift' '/go.mod' '/LICENSE'

cd test/go
grep -v 'list.*map.*list.*map' ../ThriftTest.thrift > ThriftTest.thrift
mkdir -p src/gen
thrift -out src/gen --gen \
  "go:thrift_import=github.com/apache/thrift/lib/go/thrift,package_prefix=github.com/apache/thrift/test/go/src/gen/" \
  ThriftTest.thrift
go build -buildvcs=false -o bin/ ./src/bin/testclient ./src/bin/testserver
echo "Apache Thrift $TAG cross-test peers in $DEST/test/go/bin"
