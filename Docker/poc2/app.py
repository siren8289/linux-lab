from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json

DATA = Path("/data/message.txt")


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            return self.respond(200, {"status": "ok"})
        if self.path == "/message":
            value = DATA.read_text() if DATA.exists() else ""
            return self.respond(200, {"message": value})
        self.respond(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/message":
            return self.respond(404, {"error": "not found"})
        length = int(self.headers.get("Content-Length", "0"))
        if length > 4096:
            return self.respond(413, {"error": "too large"})
        try:
            raw = self.rfile.read(length)
            payload = json.loads(raw.decode() or "{}")
            message = payload.get("message")
            if not isinstance(message, str):
                return self.respond(400, {"error": "message must be a string"})
            DATA.write_text(message)
            return self.respond(200, {"saved": True})
        except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:
            return self.respond(400, {"error": str(exc)})


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
