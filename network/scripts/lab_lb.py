#!/usr/bin/env python3
"""Round-robin stand-in for nginx lab-lb.conf.

This host has no nginx and cannot run apt or sudo. The proxy listens on
127.0.0.1:8088 and forwards to 127.0.0.1:8001 and 127.0.0.1:8002.
If the chosen backend refuses the connection, it tries the other once.
"""

import itertools
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import urllib.error
import urllib.request

BACKENDS = ("http://127.0.0.1:8001", "http://127.0.0.1:8002")
_cycle = itertools.cycle(BACKENDS)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        first = next(_cycle)
        order = (first,) + tuple(item for item in BACKENDS if item != first)
        last_error = "no backend"
        for base in order:
            try:
                with urllib.request.urlopen(base + self.path, timeout=3) as response:
                    body = response.read()
                    self.send_response(response.status)
                    content_type = response.headers.get("Content-Type", "text/html")
                    self.send_header("Content-Type", content_type)
                    self.send_header("Content-Length", str(len(body)))
                    self.send_header("X-Lab-Backend", base)
                    self.end_headers()
                    self.wfile.write(body)
                    return
            except (urllib.error.URLError, TimeoutError, OSError) as error:
                last_error = str(error)
        payload = f"bad gateway: {last_error}\n".encode()
        self.send_response(502)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 8088), Handler)
    print("lab lb listening on 127.0.0.1:8088", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
