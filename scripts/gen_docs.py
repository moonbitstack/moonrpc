#!/usr/bin/env python3
"""Generate the moonrpc API-reference page (docs/api.html) from the package
sources' `///` doc comments. Reproducible: reads the .mbt files, so the docs
never drift from the code. The output reuses docs/assets/site.css, the shared
top navigation and the section spy, so it stays one design with the rest of the
site. Run in CI and assert `git diff --exit-code` to guarantee it is current."""
import re, html, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
# One section per package, in layer order; each lists every public item in it.
SECTIONS = [
    ("wire", "wire", "wire — framing, status, metadata",
     "gRPC length-prefixed message framing, the 17-code Status and its mapping from "
     "HTTP/2 and HTTP errors, the /Service/Method path, the metadata rules that decide "
     "which keys travel base64 encoded, keepalive pings, and the HTTP/2 defaults both "
     "engines start from."),
    ("proto", "proto", "proto — protobuf and descriptors",
     "The protobuf binary wire codec (PbWriter / PbReader over the four proto3 wire "
     "types, zigzag, tag packing, unknown-field skipping, rejection of truncation and "
     "overflow) and the descriptor model with its codec to FileDescriptorProto and "
     "FileDescriptorSet bytes."),
    ("stream", "stream", "stream — stream lifecycle and handlers",
     "The RFC 9113 §5.1 stream state machine and identifier parity, the four call kinds "
     "(Unary / ServerStreaming / ClientStreaming / Bidi) and the per-call RpcContext: "
     "request metadata, the grpc-timeout deadline, and response metadata."),
    ("balance", "balance", "balance — call policy and load balancing",
     "What a client does around a call: gRPC A6 retries, throttling, pushback and "
     "hedging, the connectivity state machine, the balancers, DNS resolution and the "
     "channel pool."),
    ("client", "client", "client — the client engine",
     "H2Client allocates stream ids, builds request HEADERS and length-prefixed DATA "
     "within the send windows, and turns response frames back into a CallReply. Pure; "
     "runs in memory on every backend."),
    ("server", "server", "server — the server engine",
     "H2Server::feed turns decoded frames into the frames to send back: stream state, "
     "HPACK, connection and stream flow control, routing to a handler of any call kind, "
     "grpc-status trailers, and the interceptor chains around handlers. Pure; runs in "
     "memory on every backend."),
    ("service", "service", "service — health and reflection",
     "grpc.health.v1.Health (Check and Watch) and grpc.reflection.v1 ServerReflection "
     "(and its v1alpha alias), so grpcurl can list and describe a service."),
    ("net", "net", "net — sockets (native)",
     "GrpcServer serves the engine over a real TCP socket (h2c); Channel, the "
     "multiplexing channel and the managed channel dial one or many backends. Native "
     "only: moonbitlang/async has no JS or Wasm sockets."),
]
KIND = {"struct": "struct", "enum": "enum", "fn": "fn", "type": "type", "let": "let", "trait": "trait", "impl": "impl"}


def parse(path):
    """Return every `pub` declaration in *path* with its preceding `///` doc.

    A declaration is collected until its body opens (`{`) or it is a single-line
    `= value` form, so multi-line signatures (including `[T]` type parameters) are
    captured whole and never spill into the body."""
    items, doc = [], []
    lines = path.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        if s == "///|":
            doc = []
        elif s.startswith("///"):
            doc.append(s[3:].strip())
        elif s.startswith("pub"):
            buf = s
            is_alias = re.match(r"pub\s+(type|let|trait|impl)\b", buf) is not None
            while (not is_alias and "{" not in buf and "=" not in buf
                   and i + 1 < len(lines) and lines[i + 1].strip() != ""
                   and not lines[i + 1].strip().startswith("pub")):
                i += 1
                buf += " " + lines[i].strip()
            core = re.sub(r"\s*\{.*$", "", buf)          # drop body
            core = re.sub(r"\s*=\s*\S.*$", "", core)     # drop `= value`
            core = re.sub(r"^pub(?:\(all\))?\s+", "", core).strip()
            core = re.sub(r"\s+", " ", core).rstrip(",").rstrip()
            core = re.sub(r",\s*\)", ")", core)
            first = core.split(" ")[0] if core else ""
            items.append((KIND.get(first, "item"), core, " ".join(doc).strip()))
            doc = []
        elif s == "":
            pass
        else:
            doc = []
        i += 1
    return items


def tint(sig):
    s = html.escape(sig)
    s = re.sub(r"\b(fn|struct|enum|type|let|trait|impl|async)\b", r'<span class="k">\1</span>', s)
    s = re.sub(r"\b([A-Z][A-Za-z0-9_]*)\b", r'<span class="ty">\1</span>', s)
    s = s.replace("-&gt;", '<span class="op">-&gt;</span>').replace("?", '<span class="op">?</span>')
    return s


def prose(t):
    t = html.escape(t)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", t)


NAV = (
    '<nav class="topnav">'
    '<a class="brand" href="index.html">'
    '<svg viewBox="0 0 32 32" fill="none" aria-hidden="true">'
    '<rect x="3.5" y="3.5" width="25" height="25" style="stroke:var(--struct)" stroke-width="1.5"/>'
    '<line x1="3.5" y1="3.5" x2="28.5" y2="28.5" style="stroke:var(--struct)" stroke-width="0.75" stroke-dasharray="2 2"/>'
    '<line x1="28.5" y1="3.5" x2="3.5" y2="28.5" style="stroke:var(--struct)" stroke-width="0.75" stroke-dasharray="2 2"/>'
    '<circle cx="16" cy="16" r="4" style="fill:var(--op)"/>'
    '<circle cx="16" cy="16" r="7.5" style="stroke:var(--struct)" stroke-width="0.75"/>'
    '<circle cx="8" cy="8" r="1.6" style="fill:var(--struct)"/>'
    '<circle cx="24" cy="24" r="1.6" style="fill:var(--struct)"/>'
    '<circle cx="24" cy="8" r="1.6" style="fill:var(--struct)"/>'
    '<circle cx="8" cy="24" r="1.6" style="fill:var(--struct)"/>'
    '</svg>moonrpc</a>'
    '<div class="navlinks">'
    '<a href="index.html">Home</a>'
    '<a href="guide.html">Guide</a>'
    '<a href="api.html" class="active">API</a>'
    '<a href="showcase.html">Showcase</a>'
    '<button class="nav-theme" data-theme-toggle aria-label="toggle theme">◐ theme</button>'
    '<a class="gh" href="https://github.com/moonbitstack/moonrpc" rel="noopener">'
    '<svg viewBox="0 0 16 16" aria-hidden="true" style="fill:currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>'
    'GitHub</a>'
    '</div></nav>'
)


def main():
    HEAD = ('<!doctype html><html lang="en" data-theme="light"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>moonrpc — API reference</title>'
            '<meta name="description" content="The complete moonrpc API, generated from source: '
            'wire, proto, stream, balance, client, server, service and the native net layer.">'
            '<link rel="icon" type="image/svg+xml" href="assets/favicon.svg">'
            '<link rel="preconnect" href="https://fonts.googleapis.com">'
            '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
            '<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&'
            'family=Newsreader:opsz,wght@6..72,500;6..72,600&family=Caveat:wght@500;600&display=swap" rel="stylesheet">'
            '<link rel="stylesheet" href="assets/site.css">'
            '<script>try{var t=localStorage.getItem("moonrpc-theme");document.documentElement'
            '.setAttribute("data-theme",(t==="dark"?"dark":"light"));}catch(e){document'
            '.documentElement.setAttribute("data-theme","light");}</script>'
            '</head><body class="api-page">')

    side = [NAV, '<div class="layout"><aside class="sidebar">'
            '<div class="brand">moonrpc</div>'
            '<p class="brand-sub">MoonBit gRPC — API reference</p>'
            '<nav class="side-nav" id="section-spy">']
    side += ['<a href="#%s"><span class="at">§</span>%s</a>' % (sid, title)
             for sid, _, title, _ in SECTIONS]
    side += ['</nav>'
             '<div class="side-foot">'
             '<a href="https://github.com/moonbitstack/moonrpc" rel="noopener">'
             '<svg viewBox="0 0 16 16" aria-hidden="true" style="fill:currentColor;width:18px;height:18px"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>'
             '</a></div></aside>']

    hero = ('<main><header class="hero">'
            '<div class="eyebrow">API reference</div>'
            '<h1>Every public item, in layer order.</h1>'
            '<p class="tag">Generated from the source `///` doc-comments — it cannot drift '
            'from the code. The protocol engines are pure; the socket driver is native.</p>'
            '<div class="install"><span class="prompt">$</span>'
            '<code>moon add moonbitstack/moonrpc</code>'
            '<button class="copy" data-copy="moon add moonbitstack/moonrpc">copy</button></div>'
            '</header>')

    body = [HEAD] + side + [hero]
    total = 0
    for sid, rel, title, desc in SECTIONS:
        body.append('<section class="pkg" id="%s"><h2><span class="at">§</span>%s</h2>'
                    '<p class="pdesc">%s</p>' % (sid, title, html.escape(desc)))
        files = sorted(f for f in (ROOT / "src" / rel).glob("*.mbt")
                       if not f.stem.endswith(("_test", "_wbtest")))
        for kind, sig, doc in [it for f in files for it in parse(f)]:
            total += 1
            body.append('<div class="item" data-k="%s"><span class="kind">%s</span>'
                        '<pre class="sig">%s</pre>%s</div>'
                        % (kind, kind, tint(sig),
                           ('<p class="doc">%s</p>' % prose(doc)) if doc else ''))
        body.append('</section>')
    body.append('<footer><div class="wrap">'
                '<p><b>moonrpc</b> · MoonBit gRPC library · '
                '<a href="https://github.com/moonbitstack/moonrpc" rel="noopener">'
                'github.com/moonbitstack/moonrpc</a></p>'
                '<p class="note">Generated from source — not hand-written, so it stays honest.</p>'
                '</div></footer>')
    body.append('</main></div><script src="assets/site.js"></script></body></html>')

    out = ROOT / "docs" / "api.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(body), encoding="utf-8")
    print("wrote %s (%d public items across %d sections)" % (out, total, len(SECTIONS)))


if __name__ == "__main__":
    main()
