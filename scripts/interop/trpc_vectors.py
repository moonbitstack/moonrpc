#!/usr/bin/env python3
"""Generate the reference frames in `src/trpc/reference_wbtest.mbt`.

The frames are produced by tRPC-Python (pinned below), which is an implementation of the
same protocol written independently of this one: the point is that two encoders agree on
every octet, not that this one agrees with itself. Requests go through
`TrpcClientCodec.encode_data`, the path a real client's unary call takes. Response headers
go through the protobuf message the reference implementations marshal onto the wire
(`trpc_pb2.ResponseProtocol`), because a server's reply header is that message and nothing
else.

Run from the repository root:

    pip install trpc-python==1.0.0 protobuf
    python3 scripts/interop/trpc_vectors.py
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import trpc_sdk.abc as abc
    from trpc_sdk._inner.pb import trpc_pb2
    from trpc_sdk.codec import TrpcClientCodec
except ImportError:  # pragma: no cover - the CI installs the pin
    sys.exit("install trpc-python==1.0.0 and protobuf first")

CASES = [
    {
        "name": "unary: caller, callee and func",
        "caller": "trpc.app.client.service",
        "callee": "trpc.test.Greeter",
        "func": "/trpc.test.Greeter/SayHello",
        "timeout": 0,
        "message_type": 0,
        "serialization": 0,
        "compress": 0,
        "metadata": {},
        "body": b"\x0a\x05world",
    },
    {
        "name": "unary: a deadline",
        "caller": "trpc.app.client.service",
        "callee": "trpc.test.Greeter",
        "func": "/trpc.test.Greeter/SayHello",
        "timeout": 2000,
        "message_type": 0,
        "serialization": 0,
        "compress": 0,
        "metadata": {},
        "body": b"\x0a\x05world",
    },
    {
        "name": "unary: the dyeing mark travels in trans_info",
        "caller": "trpc.app.client.service",
        "callee": "trpc.test.Greeter",
        "func": "/trpc.test.Greeter/SayHello",
        "timeout": 150,
        "message_type": 1,
        "serialization": 0,
        "compress": 0,
        "metadata": {"trpc-dyeing-key": b"blue"},
        "body": b"\x0a\x05world",
    },
    {
        "name": "unary: a gzipped body",
        "caller": "trpc.app.client.service",
        "callee": "trpc.test.Greeter",
        "func": "/trpc.test.Greeter/SayHello",
        "timeout": 0,
        "message_type": 0,
        "serialization": 0,
        "compress": 1,
        "metadata": {},
        "body": b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03",
    },
    {
        "name": "unary: a JSON body",
        "caller": "trpc.app.client.service",
        "callee": "trpc.test.Greeter",
        "func": "/trpc.test.Greeter/SayHello",
        "timeout": 0,
        "message_type": 0,
        "serialization": 2,
        "compress": 0,
        "metadata": {},
        "body": b'{"name":"world"}',
    },
]

RESPONSES = [
    {
        "name": "response: ok",
        "request_id": 3,
        "ret": 0,
        "func_ret": 0,
        "message_type": 0,
        "serialization": 0,
        "compress": 0,
    },
    {
        "name": "response: the method is not registered",
        "request_id": 4,
        "ret": 12,
        "func_ret": 0,
        "message_type": 0,
        "serialization": 0,
        "compress": 0,
        "message": "no method is registered at /trpc.test.Greeter/SayHello",
    },
    {
        "name": "response: a business failure",
        "request_id": 5,
        "ret": 0,
        "func_ret": 3,
        "message_type": 0,
        "serialization": 0,
        "compress": 0,
        "message": "name is required",
    },
]


def hex_literal(data: bytes) -> str:
    if not data:
        return 'b""'
    body = "".join(f"\\x{byte:02x}" for byte in data)
    return f'b"{body}"'


def unary_frames() -> list[tuple[str, bytes, dict]]:
    out = []
    codec = TrpcClientCodec()
    for index, case in enumerate(CASES, start=1):
        context = abc.TrpcContext()
        message = abc.get_message(context)
        head = abc.TrpcFrameHead()
        head.set_frame_type(0)
        head.set_stream_id(index)
        message.set_frame_head(head)
        message.set_caller_service_name(case["caller"])
        message.set_callee_service_name(case["callee"])
        message.set_client_rpc_name(case["func"])
        message.set_serialization_type(case["serialization"])
        message.set_compress_type(case["compress"])
        if case["timeout"]:
            message.set_timeout(case["timeout"])
        if case["message_type"]:
            message.set_dyeing(True)
        for key, value in case["metadata"].items():
            message.client_meta_data[key] = value
        frame = codec.encode_data(context, case["body"])
        out.append((case["name"], frame, case))
    return out


def response_frames() -> list[tuple[str, bytes, dict]]:
    out = []
    for case in RESPONSES:
        protocol = trpc_pb2.ResponseProtocol()
        protocol.version = 1
        protocol.request_id = case["request_id"]
        protocol.ret = case["ret"]
        protocol.func_ret = case["func_ret"]
        protocol.content_type = case["serialization"]
        protocol.content_encoding = case["compress"]
        if case.get("message"):
            protocol.error_msg = case["message"].encode()
        out.append((case["name"], protocol.SerializeToString(), case))
    return out


def moonbit_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> None:
    unary = unary_frames()
    responses = response_frames()

    lines = [
        "// Generated by `scripts/interop/trpc_vectors.py` from tRPC-Python 1.0.0.",
        "// Do not edit: run the script instead.",
        "",
        "///|",
        "/// The octets of `bytes` as lowercase hex, which is how a mismatch reads without a",
        "/// 200-line array of decimal octets.",
        "fn to_hex(bytes : Bytes) -> String {",
        '  let mut out = ""',
        "  for byte in bytes {",
        '    let digits = "0123456789abcdef"',
        "    let value = byte.to_int()",
        '    out = out + digits[(value >> 4):(value >> 4) + 1].to_owned()',
        '    out = out + digits[(value & 15):(value & 15) + 1].to_owned()',
        "  }",
        "  out",
        "}",
        "",
        "///|",
        "/// A request the reference client encodes, and the frame it produces. The version field",
        "/// is zero here because tRPC-Python leaves it out; the head's version octet is zero for",
        "/// the same reason. `trpc/frame.mbt` writes one by default, which is what trpc-go does.",
        "fn reference_requests() -> Array[(String, Request, Bytes, Bytes)] {",
        "  [",
    ]

    for name, frame, case in unary:
        header_len = frame[8] << 8 | frame[9]
        body = frame[16 + header_len:]
        request_id = frame[10] << 24 | frame[11] << 16 | frame[12] << 8 | frame[13]
        metadata = ", ".join(
            f'("{key}", {hex_literal(value)})' for key, value in case["metadata"].items()
        )
        trans_info = f"Map([{metadata}])" if metadata else "Map([])"
        lines += [
            "    (",
            f"      {moonbit_string(name)},",
            "      Request::new(",
            "        version=0,",
            f'        caller={moonbit_string(case["caller"])},',
            f'        callee={moonbit_string(case["callee"])},',
            f'        func={moonbit_string(case["func"])},',
            f"        request_id={request_id},",
            f'        timeout={case["timeout"]},',
            f'        content_type={case["serialization"]},',
            f'        content_encoding={case["compress"]},',
            f'        message_type={case["message_type"]},',
            f"        trans_info={trans_info},",
            "      ),",
            f"      {hex_literal(body)},",
            f"      {hex_literal(frame)},",
            "    ),",
        ]
    lines += ["  ]", "}", "", "///|", "/// A response header the reference servers marshal, and the octets they publish.", "fn reference_responses() -> Array[(String, Response, Bytes)] {", "  ["]
    for name, header, case in responses:
        message = case.get("message", "")
        lines += [
            "    (",
            f"      {moonbit_string(name)},",
            "      {",
            "        let response = Response::new(",
            f"          request_id={case['request_id']},",
            f"          ret={case['ret']},",
            f"          func_ret={case['func_ret']},",
            f"          content_type={case['serialization']},",
            f"          content_encoding={case['compress']},",
            "        )",
            f"        response.error_msg = {hex_literal(message.encode())}",
            "        response",
            "      },",
            f"      {hex_literal(header)},",
            "    ),",
        ]
    lines += [
        "  ]",
        "}",
        "",
        "///|",
        "test \"reference: every request frame is the one tRPC-Python writes\" {",
        "  for case in reference_requests() {",
        "    let (name, request, body, want) = case",
        "    let header = request.encode()",
        "    let payload = @buffer.Buffer()",
        "    payload.write_bytes(header)",
        "    payload.write_bytes(body)",
        "    let frame = Frame::new(",
        "      Unary,",
        "      request.request_id.reinterpret_as_int().to_int64(),",
        "      payload.to_bytes(),",
        "      header_len=header.length(),",
        "      version=0,",
        "    )",
        "    if to_hex(frame.encode()) != to_hex(want) {",
        "      fail(name + \": \\{to_hex(frame.encode())} is not \\{to_hex(want)}\")",
        "    }",
        "  }",
        "}",
        "",
        "///|",
        "test \"reference: every response header is the one protobuf writes for it\" {",
        "  for case in reference_responses() {",
        "    let (name, response, want) = case",
        "    if to_hex(response.encode()) != to_hex(want) {",
        "      fail(name + \": \\{to_hex(response.encode())} is not \\{to_hex(want)}\")",
        "    }",
        "  }",
        "}",
        "",
        "///|",
        "test \"reference: every frame decodes to the request it was encoded from\" {",
        "  for case in reference_requests() {",
        "    let (_, request, body, want) = case",
        "    let (frame, used) = Frame::decode(want)",
        "    assert_eq(used, want.length())",
        "    assert_eq(frame.kind, Unary)",
        "    assert_eq(frame.body(), body)",
        "    let decoded = Request::decode(frame.header())",
        "    assert_eq(decoded.request_id, request.request_id)",
        "    assert_eq(decoded.timeout, request.timeout)",
        "    assert_eq(decoded.func, request.func)",
        "    assert_eq(decoded.content_encoding, request.content_encoding)",
        "  }",
        "}",
        "",
    ]

    target = Path(__file__).resolve().parents[2] / "src" / "trpc" / "reference_wbtest.mbt"
    target.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {target} with {len(unary)} request and {len(responses)} response frames")


if __name__ == "__main__":
    main()
