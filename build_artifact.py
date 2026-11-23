#!/usr/bin/env python3
"""Derive the Artifact-ready page from index.html.

Artifact pages are wrapped in <!doctype html><head>...</head><body> at publish
time, so the published file must contain page content only. site/index.html stays the
canonical standalone file; this script strips its document wrapper and re-emits
the <title> and <style> ahead of the body content.
"""
import os
import re

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "site", "index.html")
OUT = os.path.join(ROOT, "artifact.html")


def extract(pattern, text, label):
    match = re.search(pattern, text, re.DOTALL | re.IGNORECASE)
    if not match:
        raise SystemExit(f"could not find {label} in {SRC}")
    return match.group(1)


def main():
    with open(SRC, encoding="utf-8") as fh:
        html = fh.read()

    title = extract(r"<title>(.*?)</title>", html, "<title>")
    style = extract(r"(<style>.*?</style>)", html, "<style>")
    body = extract(r"<body[^>]*>(.*)</body>", html, "<body>")

    parts = [f"<title>{title}</title>", style, body.strip(), ""]
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts))

    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
