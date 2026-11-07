# Header-frame vectors

`main.go` writes the frames this repository's header transport is checked against: it builds
the same message with Apache Thrift's Go bindings (`THeaderTransport` over the binary and the
compact protocol, with and without a header block, and with the zlib transform) and prints
each frame as hex. The test in `src/thrift/header_wbtest.mbt` carries those hex strings, so
every run compares bytes with the reference implementation rather than with a restatement of
the format.

It is not part of any gate: it needs Go and the network once, and the vectors it printed are
already in the test.

```sh
cd scripts/interop/header_vectors
go run .
```
