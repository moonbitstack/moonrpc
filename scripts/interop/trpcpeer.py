#!/usr/bin/env python3
"""A tRPC peer built on tRPC-Python's own codec.

`--mode server` answers the two methods `cmd/trpcd` serves; `--mode client` calls whichever
peer is at `--addr`. Requests and replies are encoded and decoded by `TrpcClientCodec` /
`TrpcServerCodec` — the reference implementation's own view of the frame — so a run that
passes says the two stacks agree on the wire rather than that this script agrees with
itself. Reply headers are the `ResponseProtocol` message those codecs marshal.

The messages are hand-encoded protobuf, because the frame is what is under test:
`SayHelloRequest{string name = 1}`, `SayHelloReply{string text = 1, string metadata = 2}`,
`CountRequest{int32 n = 1}`, `Number{int32 value = 1}`.
"""

from __future__ import annotations

import argparse
import asyncio
import socket
import struct
import sys

import trpc_sdk.abc as abc
from trpc_sdk._inner.pb import trpc_pb2
from trpc_sdk.codec import (
    TrpcClientCodec,
    TrpcServerCodec,
    TrpcServerProtocolParser,
)

SAY_HELLO = "/trpc.test.Greeter/SayHello"
COUNT = "/trpc.test.Greeter/Count"
MAGIC = b"\x09\x30"


def varint(value: int) -> bytes:
    out = bytearray()
    while value >= 0x80:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def tag(field: int, wire: int) -> bytes:
    return varint((field << 3) | wire)


def string_field(field: int, value: str) -> bytes:
    raw = value.encode()
    return tag(field, 2) + varint(len(raw)) + raw


def int32_field(field: int, value: int) -> bytes:
    return tag(field, 0) + varint(value)


def read_fields(data: bytes):
    at = 0
    while at < len(data):
        key, at = read_varint(data, at)
        field, wire = key >> 3, key & 7
        if wire == 0:
            value, at = read_varint(data, at)
            yield field, wire, value, b""
        elif wire == 2:
            size, at = read_varint(data, at)
            yield field, wire, 0, data[at : at + size]
            at += size
        elif wire == 5:
            at += 4
        elif wire == 1:
            at += 8
        else:
            return


def read_varint(data: bytes, at: int):
    value = 0
    shift = 0
    while at < len(data):
        byte = data[at]
        at += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, at
        shift += 7
    return value, at


def decode_text(body: bytes):
    """The two strings of a reply, in field order."""
    text = ""
    metadata = ""
    for field, _, _, raw in read_fields(body):
        if field == 1:
            text = raw.decode()
        elif field == 2:
            metadata = raw.decode()
    return text, metadata


def decode_number(body: bytes) -> int:
    for field, wire, value, _ in read_fields(body):
        if field == 1 and wire == 0:
            return value
    return 0


def frame(kind_data: int, kind_stream: int, stream_id: int, header: bytes, body: bytes = b"") -> bytes:
    total = 16 + len(header) + len(body)
    head = (
        MAGIC
        + bytes([kind_data, kind_stream])
        + struct.pack(">IHI", total, len(header), stream_id)
        + bytes([1, 0])
    )
    return head + header + body


def recv_exactly(sock: socket.socket, size: int) -> bytes:
    buf = b""
    while len(buf) < size:
        chunk = sock.recv(size - len(buf))
        if not chunk:
            raise EOFError("connection closed")
        buf += chunk
    return buf


# -- client ------------------------------------------------------------------


def call(sock: socket.socket, codec: TrpcClientCodec, path: str, body: bytes):
    context = abc.TrpcContext()
    message = abc.get_message(context)
    head = abc.TrpcFrameHead()
    head.set_frame_type(0)
    head.set_stream_id(1)
    message.set_frame_head(head)
    message.set_client_rpc_name(path)
    message.set_callee_service_name("trpc.test.Greeter")
    message.set_caller_service_name("trpc.python.client.service")
    message.set_timeout(5000)
    message.set_serialization_type(0)
    message.set_compress_type(0)
    message.client_meta_data["x-test"] = b"trpc-python"
    sock.sendall(codec.encode_data(context, body))

    head_bytes = recv_exactly(sock, 16)
    total = struct.unpack(">I", head_bytes[4:8])[0]
    reply = head_bytes + recv_exactly(sock, total - 16)
    decoded = codec.decode_data(context, reply)
    response = message.client_rsp_head
    if response is not None and (response.ret != 0 or response.func_ret != 0):
        return None, response.ret + response.func_ret, response.error_msg.decode()
    return decoded, 0, ""


def stream_call(sock: socket.socket, codec: TrpcClientCodec, path: str, body: bytes):
    stream_id = 5
    context = abc.TrpcContext()
    message = abc.get_message(context)
    message.set_client_rpc_name(path)
    message.set_callee_service_name("trpc.test.Greeter")
    message.set_caller_service_name("trpc.python.client.service")
    message.set_serialization_type(0)
    message.set_compress_type(0)
    message.set_stream_id(stream_id)

    init = trpc_pb2.TrpcStreamInitMeta()
    init.request_meta.caller = b"trpc.python.client.service"
    init.request_meta.callee = b"trpc.test.Greeter"
    init.request_meta.func = path.encode()
    init.init_window_size = 65535
    message.set_stream_frame(init)
    head = abc.TrpcFrameHead()
    head.set_frame_type(1)
    head.set_frame_state(1)
    head.set_stream_id(stream_id)
    message.set_frame_head(head)
    sock.sendall(codec.encode_stream(context, b""))

    head.set_frame_state(2)
    message.set_frame_head(head)
    sock.sendall(codec.encode_stream(context, body))

    head.set_frame_state(4)
    message.set_frame_head(head)
    message.set_stream_frame(trpc_pb2.TrpcStreamCloseMeta())
    sock.sendall(codec.encode_stream(context, b""))

    values = []
    while True:
        head_bytes = recv_exactly(sock, 16)
        total = struct.unpack(">I", head_bytes[4:8])[0]
        reply = head_bytes + recv_exactly(sock, total - 16)
        state = reply[3]
        decoded = codec.decode_data(context, reply)
        if state == 1:
            meta = message.stream_frame
            if meta is not None and meta.HasField("response_meta") and meta.response_meta.ret != 0:
                return values, meta.response_meta.error_msg.decode()
        elif state == 2:
            values.append(decode_number(decoded))
        elif state == 4:
            meta = message.stream_frame
            if meta is not None and (meta.ret != 0 or meta.func_ret != 0):
                return values, meta.msg.decode()
            return values, ""


def run_client(addr: str) -> None:
    host, port = addr.rsplit(":", 1)
    sock = socket.create_connection((host, int(port)), timeout=10)
    codec = TrpcClientCodec()
    try:
        body, code, message = call(sock, codec, SAY_HELLO, string_field(1, "world"))
        if code:
            sys.exit(f"SayHello refused: {code} {message}")
        text, metadata = decode_text(body)
        print(f"SayHello  {text}  x-test={metadata}")
        if text != "Hello, world" or metadata != "trpc-python":
            sys.exit(f"SayHello answered {text!r} with x-test {metadata!r}")

        values, problem = stream_call(sock, codec, COUNT, int32_field(1, 3))
        if problem:
            sys.exit(f"Count: {problem}")
        print(f"Count     {values}")
        if values != [1, 2, 3]:
            sys.exit(f"Count answered {values}")

        _, code, message = call(sock, codec, SAY_HELLO, b"")
        print(f"refused   {code} {message}")
        if code == 0 or message != "name is required":
            sys.exit("an empty name was not refused as expected")
        print("apache peer client OK")
    finally:
        sock.close()


# -- server ------------------------------------------------------------------


def response_header(request_id: int, ret: int = 0, message: str = "") -> bytes:
    protocol = trpc_pb2.ResponseProtocol()
    protocol.version = 1
    protocol.request_id = request_id
    protocol.ret = ret
    if message:
        protocol.error_msg = message.encode()
    return protocol.SerializeToString()


def run_server(addr: str) -> None:
    host, port = addr.rsplit(":", 1)
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((host, int(port)))
    listener.listen(8)
    print(f"trpc-python peer listening on {listener.getsockname()}", flush=True)
    while True:
        conn, _ = listener.accept()
        serve_connection(conn)


def serve_connection(conn: socket.socket) -> None:
    codec = TrpcServerCodec()
    parser = TrpcServerProtocolParser()
    streams = {}
    with conn:
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                return
            parser.feed_data(chunk)
            for package in parser.read():
                for reply in answer(codec, package, streams):
                    conn.sendall(reply)


def answer(codec: TrpcServerCodec, package: bytes, streams):
    context = abc.TrpcContext()
    message = abc.get_message(context)
    body = asyncio.run(codec.decode_data(context, package))
    kind = package[2]
    stream_type = package[3]
    stream_id = struct.unpack(">I", package[10:14])[0]
    request = message.server_req_head
    if kind == 0:
        path = request.func.decode()
        if path == SAY_HELLO:
            name = ""
            for field, _, _, raw in read_fields(body):
                if field == 1:
                    name = raw.decode()
            if not name:
                header = response_header(request.request_id, 51, "name is required")
                return [frame(0, 0, request.request_id, header)]
            reply = string_field(1, "Hello, " + name)
            if "x-test" in request.trans_info:
                reply += string_field(2, request.trans_info["x-test"].decode())
            header = response_header(request.request_id)
            return [frame(0, 0, request.request_id, header, reply)]
        header = response_header(request.request_id, 12, f"no method is registered at {path}")
        return [frame(0, 0, request.request_id, header)]

    if stream_type == 1:
        meta = message.stream_frame
        streams[stream_id] = {"path": meta.request_meta.func.decode(), "body": b""}
        response = trpc_pb2.TrpcStreamInitMeta()
        response.response_meta.ret = 0
        response.init_window_size = 65535
        return [frame(1, 1, stream_id, b"", response.SerializeToString())]
    if stream_type == 2:
        if stream_id in streams:
            streams[stream_id]["body"] += body
        return []
    if stream_type == 4:
        state = streams.pop(stream_id, None)
        if state is None:
            return []
        out = []
        closing = trpc_pb2.TrpcStreamCloseMeta()
        if state["path"] == COUNT:
            for i in range(1, decode_number(state["body"]) + 1):
                out.append(frame(1, 2, stream_id, b"", int32_field(1, i)))
        else:
            closing.ret = 12
            closing.msg = b"no streaming method is registered at " + state["path"].encode()
        out.append(frame(1, 4, stream_id, b"", closing.SerializeToString()))
        return out
    return []


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["server", "client"], default="server")
    parser.add_argument("--addr", default="127.0.0.1:12000")
    args = parser.parse_args()
    if args.mode == "client":
        run_client(args.addr)
    else:
        run_server(args.addr)


if __name__ == "__main__":
    main()
