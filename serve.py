#!/usr/bin/env python3
"""Minimal static server for local preview of the score calculator.

Serves site/ (the folder that gets deployed). localhost counts as a secure
context, so the service worker and "Install app" work here as they will in
production.
"""
import functools
import http.server
import os
import socketserver

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(ROOT, "site")
HOST = os.environ.get("HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", "8777"))


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".webmanifest": "application/manifest+json",
        ".js": "text/javascript",
        ".svg": "image/svg+xml",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    handler = functools.partial(Handler, directory=SITE)
    with socketserver.TCPServer((HOST, PORT), handler) as httpd:
        print(f"serving {SITE} on http://{HOST}:{PORT}", flush=True)
        httpd.serve_forever()
