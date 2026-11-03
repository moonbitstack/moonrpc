#!/usr/bin/env python3
"""Generate the guide's three writing-style variants from the runnable packages
under src/examples/guide/. Each variant's source and recorded output are read
from a package that `moon run` actually executes, so the guide cannot drift from
the API. `--check` fails when docs/guide.html is out of date; CI runs it."""
import html
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GUIDE = ROOT / "docs" / "guide.html"
BEGIN = "<!-- BEGIN guide-styles -->"
END = "<!-- END guide-styles -->"

# (key, label, source file, package under src/examples/guide)
VARIANTS = [
    ("annotation", "Annotation", "src/examples/guide/annotation/service.mbt", "annotation"),
    ("functional", "Functional", "src/examples/guide/functional/main.mbt", "functional"),
    ("class", "Class", "src/examples/guide/class/main.mbt", "class"),
]


def run(pkg):
    result = subprocess.run(
        ["moon", "run", f"src/examples/guide/{pkg}", "--target", "native"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"moon run {pkg} failed:\n{result.stderr}")
    return result.stdout.strip()


def render():
    blocks = []
    for key, label, source, pkg in VARIANTS:
        code = (ROOT / source).read_text(encoding="utf-8").strip()
        out = run(pkg)
        blocks.append(
            f'<div class="variant" data-style="{key}">'
            f'<div class="vhead">{label}</div>'
            f"<pre><code>{html.escape(code)}</code></pre>"
            f'<pre class="out"><code>{html.escape(out)}</code></pre>'
            f"</div>"
        )
    return (
        '<div class="styles" data-style-group data-active="annotation">\n'
        + "\n".join(blocks)
        + "\n</div>"
    )


def main():
    text = GUIDE.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        raise SystemExit("docs/guide.html has no guide-styles markers")
    block = BEGIN + "\n" + render() + "\n" + END
    new = re.sub(
        re.escape(BEGIN) + r".*?" + re.escape(END),
        lambda _m: block,
        text,
        flags=re.S,
    )
    if "--check" in sys.argv:
        if new != text:
            print(
                "docs/guide.html is out of date; run scripts/gen_guide.py",
                file=sys.stderr,
            )
            return 1
        return 0
    GUIDE.write_text(new, encoding="utf-8")
    print("updated docs/guide.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
