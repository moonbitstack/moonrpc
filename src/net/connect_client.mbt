// The transport a Connect client uses over HTTP/1.1: one POST per call, the reply read whole.

///|
/// An HTTP/1.1 endpoint a Connect client posts to. Every call opens its own connection, which
/// is what a client that answers one call at a time needs and what a proxy in front of a
/// server sees most often.
pub(all) struct Http1Transport {
  host : String
  port : Int32
}

///|
pub fn Http1Transport::new(host : String, port : Int32) -> Http1Transport {
  { host, port, }
}

///|
pub impl @connect.Transport for Http1Transport with fn post(
  self,
  path,
  content,
  body,
  headers,
) {
  let conn = @tcp.dial(self.host, port=self.port)
  defer conn.close()
  let http = @http1.Conn::new(@http1.Role::Client)
  let fields : Array[@header.Header] = [
    @header.Header::of("host", self.host),
    @header.Header::of("accept", "*/*"),
  ]
  for h in headers {
    fields.push(h)
  }
  let request = @http1.Request::of(
    "POST",
    path,
    fields~,
    body=@http1.Body::Sized(body.length()),
  )
  conn.write(http.send(@http1.Event::Request(request)))
  if body.length() > 0 {
    conn.write(http.send(@http1.Event::Data(body)))
  }
  conn.write(http.send(@http1.Event::End([])))
  ignore(content)
  let status = Ref(0)
  let answer = Buffer()
  let reply_headers : Array[@header.Header] = []
  for ;; {
    let event = http.next() catch { _ => break }
    match event {
      @http1.Event::Response(response) => {
        status.val = response.status
        for f in response.fields {
          reply_headers.push(f)
        }
      }
      @http1.Event::Data(bytes) => answer.write_bytes(bytes)
      @http1.Event::End(_extra) => break
      @http1.Event::NeedData => {
        let more = conn.read_some() catch { _ => break }
        let chunk = match more {
          Some(bytes) => bytes
          None => break
        }
        if chunk.length() == 0 {
          break
        }
        http.receive(chunk[:])
      }
      _ => break
    }
  }
  (status.val, reply_headers, answer.to_bytes())
}

///|
pub extend Http1Transport with @connect.Transport::{post}
