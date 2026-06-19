#!/usr/bin/env python3
"""Render a markdown implementation plan into a self-contained, styled HTML
page and serve it on a local HTTP server.

The generated HTML inlines marked.js + CSS + the plan markdown, so the served
file has zero runtime dependencies (one file, renders offline in any browser).
The HTTP server is launched detached so it keeps serving after this script
exits; it prints the clickable URL and the server PID.

Usage:
    python3 serve_plan.py PLAN.md [--title "Feature X Plan"] [--port 0]

Outputs (last two lines, stable for parsing):
    URL: http://127.0.0.1:<port>/<name>.html
    PID: <server-pid>
"""
import argparse
import os
import socket
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE.parent / "assets" / "template.html"
MARKED = HERE.parent / "assets" / "marked.min.js"
HLJS_JS = HERE.parent / "assets" / "highlight.min.js"
HLJS_CSS = HERE.parent / "assets" / "atom-one-dark.min.css"


def free_port() -> int:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("markdown", help="path to the plan markdown file")
    ap.add_argument("--title", default=None, help="page <title> (defaults to first H1 or filename)")
    ap.add_argument("--port", type=int, default=0, help="port to serve on (0 = auto-pick free port)")
    args = ap.parse_args()

    md_path = Path(args.markdown).resolve()
    if not md_path.exists():
        print(f"error: markdown file not found: {md_path}", file=sys.stderr)
        return 1

    md = md_path.read_text(encoding="utf-8")
    # Prevent the embedded markdown from prematurely closing its <script> host.
    md_safe = md.replace("</script", "<\\/script")

    title = args.title
    if not title:
        for line in md.splitlines():
            if line.startswith("# "):
                title = line[2:].strip()
                break
        title = title or md_path.stem

    template = TEMPLATE.read_text(encoding="utf-8")
    marked_js = MARKED.read_text(encoding="utf-8")
    hljs_js = HLJS_JS.read_text(encoding="utf-8")
    hljs_css = HLJS_CSS.read_text(encoding="utf-8")

    html = (
        template
        .replace("__PLAN_TITLE__", title)
        .replace("__HLJS_CSS__", hljs_css)
        .replace("__MARKED_JS__", marked_js)
        .replace("__HLJS_JS__", hljs_js)
        .replace("__PLAN_MARKDOWN__", md_safe)
    )

    out_html = md_path.with_suffix(".html")
    out_html.write_text(html, encoding="utf-8")

    port = args.port or free_port()
    # Detached server rooted at the plan's directory. start_new_session so it
    # survives this script (and the calling agent's shell) exiting.
    log = open(os.devnull, "wb")
    proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port),
         "--bind", "127.0.0.1", "--directory", str(out_html.parent)],
        stdout=log, stderr=log, start_new_session=True,
    )

    url = f"http://127.0.0.1:{port}/{out_html.name}"
    print(f"HTML: {out_html}")
    print(f"URL: {url}")
    print(f"PID: {proc.pid}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
