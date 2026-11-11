// Write src/thrift/json_vectors_wbtest.mbt: the bytes Apache Thrift's own TJSONProtocol
// writes for a handful of messages. The test reads every vector with this repository's
// implementation and writes it out again, and the bytes have to be the same — so a wrong
// type name, a missing comma, base64 where the reference writes text, or a field id written
// bare instead of quoted all show up as a diff.
//
// Doubles are the one exception, and they are the reason the vectors hold only the values
// both implementations spell alike: Go formats a number with `strconv.FormatFloat(v, 'g',
// -1, 64)` — `1e+06` for a million — and this language writes `1000000`. Both are JSON
// numbers that read back as the same double, so the vectors carry the ones that agree and
// the corner values get tests of their own.
//
//     cd scripts/interop && go run ./thriftjson
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/apache/thrift/lib/go/thrift"
)

// A message the reference implementation writes: its label and the calls that fill it.
type vector struct {
	label string
	write func(ctx context.Context, p thrift.TProtocol)
}

// call opens a CALL and its argument struct, which is what a generated client does before it
// writes the first argument.
func call(name string, seqid int32) func(thrift.TProtocol, context.Context) {
	return func(p thrift.TProtocol, ctx context.Context) {
		must(p.WriteMessageBegin(ctx, name, thrift.CALL, seqid))
		must(p.WriteStructBegin(ctx, name+"_args"))
	}
}

func main() {
	out := flag.String("o", "", "the MoonBit file to write")
	flag.Parse()
	if *out == "" {
		*out = filepath.Join("..", "..", "src", "thrift", "json_vectors_wbtest.mbt")
	}

	vectors := []vector{
		{
			label: "every scalar",
			write: func(ctx context.Context, p thrift.TProtocol) {
				call("ping", 7)(p, ctx)
				field(p, ctx, thrift.BOOL, 1, func() { p.WriteBool(ctx, true) })
				field(p, ctx, thrift.BYTE, 2, func() { p.WriteByte(ctx, -3) })
				field(p, ctx, thrift.I16, 3, func() { p.WriteI16(ctx, -300) })
				field(p, ctx, thrift.I32, 4, func() { p.WriteI32(ctx, -70000) })
				field(p, ctx, thrift.I64, 5, func() { p.WriteI64(ctx, -9000000000) })
				field(p, ctx, thrift.DOUBLE, 6, func() { p.WriteDouble(ctx, 1.5) })
				field(p, ctx, thrift.STRING, 7, func() { p.WriteString(ctx, "hello") })
				field(p, ctx, thrift.STRING, 8, func() {
					p.WriteBinary(ctx, []byte{0, 1, 0x7f, 0xff})
				})
				field(p, ctx, thrift.UUID, 9, func() {
					p.WriteUUID(ctx, thrift.Tuuid{
						0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
						0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
					})
				})
				closeStruct(p, ctx)
				must(p.WriteMessageEnd(ctx))
			},
		},
		{
			label: "a string that needs escaping",
			write: func(ctx context.Context, p thrift.TProtocol) {
				call("echo", 2)(p, ctx)
				field(p, ctx, thrift.STRING, 1, func() {
					p.WriteString(ctx, "a\"b\\c<d>e&f\n\ta\x01b 中文 🙂")
				})
				closeStruct(p, ctx)
				must(p.WriteMessageEnd(ctx))
			},
		},
		{
			label: "empty containers and an empty struct",
			write: func(ctx context.Context, p thrift.TProtocol) {
				call("empty", 3)(p, ctx)
				field(p, ctx, thrift.LIST, 1, func() {
					must(p.WriteListBegin(ctx, thrift.I32, 0))
					p.WriteListEnd(ctx)
				})
				field(p, ctx, thrift.MAP, 2, func() {
					must(p.WriteMapBegin(ctx, thrift.STRING, thrift.I32, 0))
					p.WriteMapEnd(ctx)
				})
				field(p, ctx, thrift.STRUCT, 3, func() {
					must(p.WriteStructBegin(ctx, "Empty"))
					closeStruct(p, ctx)
				})
				closeStruct(p, ctx)
				must(p.WriteMessageEnd(ctx))
			},
		},
		{
			label: "lists, sets and maps of every shape",
			write: func(ctx context.Context, p thrift.TProtocol) {
				call("containers", 4)(p, ctx)
				field(p, ctx, thrift.LIST, 1, func() {
					must(p.WriteListBegin(ctx, thrift.I32, 3))
					for _, v := range []int32{1, -2, 300} {
						p.WriteI32(ctx, v)
					}
					p.WriteListEnd(ctx)
				})
				field(p, ctx, thrift.SET, 2, func() {
					must(p.WriteSetBegin(ctx, thrift.STRING, 2))
					p.WriteString(ctx, "b")
					p.WriteString(ctx, "a")
					p.WriteSetEnd(ctx)
				})
				field(p, ctx, thrift.MAP, 3, func() {
					must(p.WriteMapBegin(ctx, thrift.I32, thrift.STRING, 2))
					p.WriteI32(ctx, 1)
					p.WriteString(ctx, "one")
					p.WriteI32(ctx, -2)
					p.WriteString(ctx, "minus two")
					p.WriteMapEnd(ctx)
				})
				field(p, ctx, thrift.LIST, 4, func() {
					must(p.WriteListBegin(ctx, thrift.STRUCT, 2))
					for _, name := range []string{"first", "second"} {
						must(p.WriteStructBegin(ctx, "Item"))
						field(p, ctx, thrift.STRING, 1, func() { p.WriteString(ctx, name) })
						field(p, ctx, thrift.LIST, 2, func() {
							must(p.WriteListBegin(ctx, thrift.I16, 1))
							p.WriteI16(ctx, 9)
							p.WriteListEnd(ctx)
						})
						closeStruct(p, ctx)
					}
					p.WriteListEnd(ctx)
				})
				field(p, ctx, thrift.MAP, 5, func() {
					must(p.WriteMapBegin(ctx, thrift.STRING, thrift.LIST, 1))
					p.WriteString(ctx, "k")
					must(p.WriteListBegin(ctx, thrift.BOOL, 2))
					p.WriteBool(ctx, true)
					p.WriteBool(ctx, false)
					p.WriteListEnd(ctx)
					p.WriteMapEnd(ctx)
				})
				closeStruct(p, ctx)
				must(p.WriteMessageEnd(ctx))
			},
		},
		{
			label: "a reply whose result is a struct with an exception beside it",
			write: func(ctx context.Context, p thrift.TProtocol) {
				must(p.WriteMessageBegin(ctx, "fail", thrift.REPLY, 5))
				must(p.WriteStructBegin(ctx, "fail_result"))
				field(p, ctx, thrift.STRUCT, 0, func() {
					must(p.WriteStructBegin(ctx, "Result"))
					field(p, ctx, thrift.I32, 1, func() { p.WriteI32(ctx, 42) })
					field(p, ctx, thrift.DOUBLE, 2, func() { p.WriteDouble(ctx, 0.25) })
					closeStruct(p, ctx)
				})
				field(p, ctx, thrift.STRUCT, 1, func() {
					must(p.WriteStructBegin(ctx, "Boom"))
					field(p, ctx, thrift.STRING, 1, func() { p.WriteString(ctx, "boom") })
					closeStruct(p, ctx)
				})
				closeStruct(p, ctx)
				must(p.WriteMessageEnd(ctx))
			},
		},
	}

	var body []string
	body = append(body,
		"// The bytes Apache Thrift's Go TJSONProtocol writes for a set of messages, and a reader",
		"// that must agree with them: every vector is read by this package's protocol and written",
		"// again, and the two have to be the same octets. Generated by `scripts/interop/thriftjson`",
		"// from the reference implementation; do not edit.",
		"",
		"///|",
		"/// The vectors, labelled, exactly as the reference implementation spells them.",
		"let json_vectors : Array[(String, String)] = [",
	)
	for _, v := range vectors {
		buf := thrift.NewTMemoryBuffer()
		p := thrift.NewTJSONProtocol(buf)
		ctx := context.Background()
		v.write(ctx, p)
		must(p.Flush(ctx))
		body = append(body, fmt.Sprintf("  (%s, %s),", quote(v.label), quote(buf.String())))
	}
	body = append(body, "]", "")
	body = append(body, strings.Split(tests, "\n")...)

	text := strings.Join(body, "\n")
	if err := os.WriteFile(*out, []byte(text), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("wrote %s with %d vectors\n", *out, len(vectors))
}

// tests is everything after the vectors: a reader that copies one message from one protocol
// into another, and what it asserts.
const tests = `///|
/// Copy one message from a reader into a writer, value by value. It is what makes a vector a
/// test of both directions: the reference implementation's bytes go in, this package's
/// protocol reads them, and what it writes goes out for comparison.
fn transcode(src : &Protocol, dst : &Protocol) -> Unit raise ThriftError {
  let (name, kind, seqid) = src.read_message_begin()
  dst.write_message_begin(name, kind, seqid)
  src.read_struct_begin()
  dst.write_struct_begin(name)
  copy_fields(src, dst)
  src.read_struct_end()
  dst.write_struct_end()
  src.read_message_end()
  dst.write_message_end()
}

///|
fn copy_fields(src : &Protocol, dst : &Protocol) -> Unit raise ThriftError {
  for ;; {
    let (type_, id) = src.read_field_begin()
    if type_ == type_stop {
      dst.write_field_stop()
      break
    }
    dst.write_field_begin(type_, id)
    copy_value(src, dst, type_)
  }
}

///|
fn copy_value(src : &Protocol, dst : &Protocol, type_ : Int32) -> Unit raise ThriftError {
  match type_ {
    t if t == type_bool => dst.write_bool(src.read_bool())
    t if t == type_byte => dst.write_byte(src.read_byte())
    t if t == type_i16 => dst.write_i16(src.read_i16())
    t if t == type_i32 => dst.write_i32(src.read_i32())
    t if t == type_i64 => dst.write_i64(src.read_i64())
    t if t == type_double => dst.write_double(src.read_double())
    t if t == type_string => dst.write_string(src.read_string())
    t if t == type_uuid => dst.write_uuid(src.read_uuid())
    t if t == type_struct => {
      src.read_struct_begin()
      dst.write_struct_begin("")
      copy_fields(src, dst)
      src.read_struct_end()
      dst.write_struct_end()
    }
    t if t == type_list => {
      let (elem, size) = src.read_list_begin()
      dst.write_list_begin(elem, size)
      for _ in 0..<size {
        copy_value(src, dst, elem)
      }
    }
    t if t == type_set => {
      let (elem, size) = src.read_set_begin()
      dst.write_set_begin(elem, size)
      for _ in 0..<size {
        copy_value(src, dst, elem)
      }
    }
    t if t == type_map => {
      let (key, value, size) = src.read_map_begin()
      dst.write_map_begin(key, value, size)
      for _ in 0..<size {
        copy_value(src, dst, key)
        copy_value(src, dst, value)
      }
    }
    other => abort("a value of a type the vectors do not carry: " + other.to_string())
  }
}

///|
test "the reference implementation's bytes read and write back unchanged" {
  for pair in json_vectors {
    let (label, text) = pair
    let bytes = @utf8.encode(text)
    let src : &Protocol = Json::new(b"")
    // The unframed transport asks this of every buffer it grows: how long is the message at
    // the front, if it is all there.
    let len = message_len(src, bytes) catch {
      e => abort(label + ": message_len: " + e.to_string())
    }
    assert_eq(len, Some(bytes.length()))
    // Finding the end walked the message; the copy starts from its front again.
    src.reset(bytes)
    let dst = Json::new(b"")
    transcode(src, dst) catch {
      e => abort(label + ": transcode: " + e.to_string())
    }
    assert_eq(src.consumed(), bytes.length())
    assert_eq(@utf8.decode_lossy(dst.output()), text)
  }
}

///|
test "a message that stops in the middle is not a message" {
  for pair in json_vectors {
    let bytes = @utf8.encode(pair.1)
    for cut in [1, bytes.length() / 2, bytes.length() - 1] {
      let src = Json::new(b"")
      let length = message_len(src, bytes[:cut].to_owned())
      assert_eq(length, None)
    }
  }
}

///|
test "doubles the protocol quotes, and the ones JSON spells as a number" {
  // The three values a JSON number cannot hold travel as strings, as the reference
  // implementation writes them.
  let cases : Array[(Double, String)] = [
    (@double.not_a_number, "\"NaN\""),
    (@double.infinity, "\"Infinity\""),
    (@double.neg_infinity, "\"-Infinity\""),
    (1.5, "1.5"),
    (0.1, "0.1"),
  ]
  for pair in cases {
    let (value, text) = pair
    let writer = Json::new(b"")
    writer.write_double(value)
    assert_eq(@utf8.decode_lossy(writer.output()), text)
    let reader = Json::new(writer.output())
    let back = reader.read_double()
    if value.is_nan() {
      assert_true(back.is_nan())
    } else {
      assert_eq(back, value)
    }
  }
}

///|
test "a message the protocol did not write is refused, not guessed at" {
  // A field whose type name this protocol does not define. A reader that accepted it would
  // report the wrong type and read the wrong number of octets.
  let reader = Json::new(
    @utf8.encode("[1,\"m\",1,1,{\"1\":{\"i33\":1}}]"),
  )
  let outcome : Result[Unit, ThriftError] = Ok(
    transcode_from(reader),
  ) catch {
    e => Err(e)
  }
  match outcome {
    Ok(_) => abort("an unknown type name was accepted")
    Err(Unsupported(_)) | Err(Malformed(_)) => ()
    Err(other) => abort("an unknown type name was " + other.to_string())
  }
}

///|
fn transcode_from(reader : &Protocol) -> Unit raise ThriftError {
  let writer = Json::new(b"")
  transcode(reader, writer)
}
`
// field writes one field of a struct: its header, what fills it, and the close.
func field(
	p thrift.TProtocol,
	ctx context.Context,
	t thrift.TType,
	id int16,
	fill func(),
) {
	must(p.WriteFieldBegin(ctx, "", t, id))
	fill()
	p.WriteFieldEnd(ctx)
}

// closeStruct ends the fields of a struct and the struct itself.
func closeStruct(p thrift.TProtocol, ctx context.Context) {
	p.WriteFieldStop(ctx)
	p.WriteStructEnd(ctx)
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

// quote turns a string into a MoonBit literal.
func quote(text string) string {
	var out strings.Builder
	out.WriteByte('"')
	for _, r := range text {
		switch r {
		case '"':
			out.WriteString("\\\"")
		case '\\':
			out.WriteString("\\\\")
		case '\n':
			out.WriteString("\\n")
		case '\r':
			out.WriteString("\\r")
		case '\t':
			out.WriteString("\\t")
		default:
			if r < 0x20 {
				out.WriteString(fmt.Sprintf("\\u{%02X}", r))
			} else {
				out.WriteRune(r)
			}
		}
	}
	out.WriteByte('"')
	return out.String()
}
