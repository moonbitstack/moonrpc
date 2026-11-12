// Connect's GET form. A unary call marked idempotent may travel as a GET with the message in
// the query string: `connect=v1&encoding=<codec>&message=<base64url>&base64=1`, plus
// `compression=<name>` when the message was compressed. There is no request body, and the
// content type is carried by `encoding` instead of a header. The reply is an ordinary unary
// response. Both halves live here so the two HTTP drivers only move bytes.

///|
/// The codec name a query's `encoding` parameter carries.
pub fn codec_query_name(content : Content) -> String {
  match content.codec {
    Proto => "proto"
    Json => "json"
  }
}

///|
/// A GET target for one message. Base64 is URL-safe and unpadded, so the value needs no
/// percent-encoding; the protocol's own query parameters are all unreserved characters.
pub fn get_target(
  path : String,
  content : Content,
  message : Bytes,
  compression : String,
) -> String {
  let encoded = @base64.encode(message[:], kind=@base64.Url, padding=false)
  let mut query = "connect=v1&encoding=" +
    codec_query_name(content) +
    "&message=" +
    encoded +
    "&base64=1"
  if compression != "identity" {
    query = query + "&compression=" + compression
  }
  path + "?" + query
}

///|
/// Whether a request target is the GET form of a Connect call.
pub fn is_get_target(target : String) -> Bool {
  target.find("?") is Some(_)
}

///|
/// Read a percent-encoded octet. The base64url value never needs it, but a peer is allowed to
/// escape any query value and a reader that ignored `%XX` would hand the wrong bytes on.
fn percent_decode(text : String) -> String {
  let bytes = @utf8.encode(text)
  let out = Buffer()
  let mut at = 0
  while at < bytes.length() {
    if bytes[at] == b'%' && at + 2 < bytes.length() {
      let hi = hex_digit(bytes[at + 1].to_int())
      let lo = hex_digit(bytes[at + 2].to_int())
      if hi >= 0 && lo >= 0 {
        out.write_byte((hi * 16 + lo).to_byte())
        at = at + 3
        continue
      }
    }
    out.write_byte(bytes[at])
    at = at + 1
  }
  @utf8.decode_lossy(out.to_bytes())
}

///|
fn hex_digit(value : Int32) -> Int32 {
  if value >= 0x30 && value <= 0x39 {
    value - 0x30
  } else if value >= 0x61 && value <= 0x66 {
    value - 0x61 + 10
  } else if value >= 0x41 && value <= 0x46 {
    value - 0x41 + 10
  } else {
    -1
  }
}

///|
fn query_value(query : String, name : String) -> String? {
  for part in query.split("&") {
    let text = part.to_owned()
    match text.find("=") {
      Some(at) => {
        let key = text.exact_view(start=0, end=at).to_owned()
        let value = text.exact_view(start=at + 1, end=text.length()).to_owned()
        if key == name {
          return Some(percent_decode(value))
        }
      }
      None => ()
    }
  }
  None
}

///|
/// Turn a GET target and its headers into the ordinary unary `Request` the dispatch reads.
/// `None` means the query is not a Connect GET body at all.
pub fn parse_get_request(
  target : String,
  headers : Array[@header.Header],
) -> Request? {
  let at = match target.find("?") {
    Some(at) => at
    None => return None
  }
  let path = target.exact_view(start=0, end=at).to_owned()
  let query = target.exact_view(start=at + 1, end=target.length()).to_owned()
  let encoding = match query_value(query, "encoding") {
    Some(name) => name
    None => "proto"
  }
  let text = match query_value(query, "message") {
    Some(text) => text
    None => return None
  }
  let body = if query_value(query, "base64") == Some("1") {
    @base64.decode(text[:], kind=@base64.Url, padding=false) catch {
      _ => return None
    }
  } else {
    @utf8.encode(text)
  }
  let content_type = if encoding == "json" {
    "application/json"
  } else {
    "application/proto"
  }
  let fields : Array[@header.Header] = [
    { name: b"content-type", value: @utf8.encode(content_type), },
  ]
  for h in headers {
    let name = @utf8.decode_lossy(h.name).to_lower()
    if name != "content-type" &&
      name != "content-encoding" &&
      name != "content-length" &&
      !name.has_prefix(":") {
      fields.push(h)
    }
  }
  // A compressed GET message names its algorithm in the query, not in a header. Adding the
  // header here is what makes the ordinary unary decompression path read it.
  match query_value(query, "compression") {
    Some(name) =>
      fields.push({ name: b"content-encoding", value: @utf8.encode(name), })
    None => ()
  }
  Some({ path, headers: fields, body, })
}
