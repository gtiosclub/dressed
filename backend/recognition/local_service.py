"""Loopback-only fixture bridge for iOS simulator recognition checks.

It reads a saved response and makes no provider or paid network request.
"""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from object_localization import parse_response


MAX_IMAGE_BYTES = 5_000_000


class Handler(BaseHTTPRequestHandler):
    fixture: dict | None = None

    def do_POST(self) -> None:
        if self.path != "/recognize":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size <= 0 or size > MAX_IMAGE_BYTES:
                raise ValueError("image must be 1 byte to 5 MB")
            import_id = self.headers.get("X-Import-ID", "")
            if not import_id or len(import_id) > 100:
                raise ValueError("invalid import ID")
            self.rfile.read(size)
            if self.fixture is None:
                raise RuntimeError("service has no response source")
            result = parse_response(self.fixture, import_id)
            encoded = json.dumps(result).encode()
            self.send_response(200)
        except (ValueError, RuntimeError) as error:
            encoded = json.dumps({"error": str(error)}).encode()
            self.send_response(400)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        # HTTP logs could expose import IDs; this prototype prints only startup.
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    Handler.fixture = json.loads(args.fixture.read_text())
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Dressed fixture recognition service on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
