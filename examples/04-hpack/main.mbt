// Complete HPACK (RFC 7541): the header-compression stack a gRPC connection runs on.
// The 61-entry static table, prefix integers (§5.1), string literals with Huffman
// coding (§5.2, Appendix B), and the size-bounded dynamic table with eviction (§4).
// This drives each primitive on its own, then the stateful encoder/decoder pair over
// a header list, printing the compressed bytes and the exact round-trip.
//
//     moon run examples/04-hpack

///|
#coverage.skip
fn main {
  run() catch {
    e => println("error: \{e}")
  }
}

///|
fn run() -> Unit raise {
  // The static table indexes the header fields every request repeats. Index 2 is the
  // `:method GET` entry; index 8 is `:status 200`.
  let table = @hpack.static_table
  println("static table: \{table.length()} entries")
  match @hpack.entry(2) {
    Some(h) => println("  [2] = \{h.ascii().0}: \{h.ascii().1}")
    None => ()
  }
  match @hpack.entry(8) {
    Some(h) => println("  [8] = \{h.ascii().0}: \{h.ascii().1}")
    None => ()
  }

  // Prefix integers (§5.1): a value below the prefix max fits one octet; 1337 with a
  // 5-bit prefix spills into continuation octets. The arithmetic is `moonvar`'s, since
  // QPACK counts in the same integer and neither of them owns it.
  for value in [10, 31, 1337, 66666] {
    let enc = @prefix.encode(value, prefix=5)
    let status = try {
      let (back, consumed) = @prefix.decode(enc[:], prefix=5)
      if back == value && consumed == enc.length() {
        "ok"
      } else {
        "MISMATCH"
      }
    } catch {
      e => "raised \{e}"
    }
    println(
      "  int \{value} (5-bit prefix) = \{@base16.encode(enc)} (\{status})",
    )
  }

  // String literals (§5.2): the raw form and the Huffman form of the same octets. The
  // `auto` encoder keeps whichever is shorter, setting the `H` bit when it Huffman-codes.
  let host = b"www.example.com"
  let raw = @hpack.string(host[:], huffman=false)
  let huff = @hpack.string(host[:])
  let auto = @hpack.string(host[:])
  println("string \"www.example.com\":")
  println("  raw     \{raw.length()} octets, H=\{@prefix.flagged(raw[:])}")
  println(
    "  huffman \{huff.length()} octets, H=\{@prefix.flagged(huff[:])}  (§C.4.1: \{@base16.encode(@huffman.encode(host))})",
  )
  println("  auto picks the huffman form: \{auto == huff}")
  let (read_back, _) = @hpack.read_string(auto, 0)
  println("  decoded back: \{read_back == host}")

  // The dynamic table (§4): a FIFO of recently seen fields, each costing
  // `name + value + 32` octets, bounded by its max size. Filling past the bound evicts
  // the oldest entry; shrinking the bound evicts to fit.
  let tbl = @hpack.Table::new(limit=100)
  tbl.add(b"custom-key", b"heke1228")
  tbl.add(b"x-trace-id", b"23333")
  println("dynamic table: \{tbl.count()} entries, \{tbl.size()}/100 octets")
  tbl.add(b"another-header", b"a fairly long value that forces eviction")
  println(
    "  after a large insert: \{tbl.count()} entries, \{tbl.size()}/100 octets",
  )
  tbl.resize(40)
  println(
    "  after shrinking to 40: \{tbl.count()} entries, \{tbl.size()}/40 octets",
  )
  println("  size-update opcode: \{@base16.encode(@hpack.size_update(40))}")

  // The stateful encoder/decoder pair over a real header list — the block a client puts
  // in a HEADERS frame, decoded back to the same fields.
  let enc = @hpack.Encoder::new(huffman=true)
  let headers : Array[@header.Header] = [
    { name: b":method", value: b"POST", },
    { name: b":path", value: b"/greet.Greeter/SayHello", },
    { name: b":authority", value: b"www.example.com", },
    { name: b"content-type", value: b"application/grpc+proto", },
  ]
  let block = enc.encode(headers)
  let dec = @hpack.Decoder::new()
  let decoded = dec.decode(block)
  println(
    "header block: \{headers.length()} fields -> \{block.length()} octets -> \{decoded.length()} fields, round-trip \{decoded == headers}",
  )
}
