"""Loopback-only recognition bridge for iOS simulator development."""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock

from google_vision import recognize
from object_localization import parse_response


MAX_IMAGE_BYTES = 5_000_000


class Handler(BaseHTTPRequestHandler):
    fixture: dict | None = None
    live_project: str | None = None
    request_limit = 20
    request_count = 0
    request_lock = Lock()

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
            image = self.rfile.read(size)
            if self.live_project:
                with self.request_lock:
                    if self.request_count >= self.request_limit:
                        raise RuntimeError("this service's live request limit is reached; restart only after checking usage")
                    self.__class__.request_count += 1
                response = recognize(image, self.live_project)
            elif self.fixture is not None:
                response = self.fixture
            else:
                raise RuntimeError("service has no response source")
            result = parse_response(response, import_id)
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
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--fixture", type=Path)
    source.add_argument("--live-project", help="Google Cloud project for paid Object Localization calls")
    parser.add_argument("--max-live-requests", type=int, default=20,
                        help="maximum paid calls in this service process (default: 20)")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if args.max_live_requests < 1 or args.max_live_requests > 100:
        parser.error("--max-live-requests must be between 1 and 100")
    Handler.fixture = json.loads(args.fixture.read_text()) if args.fixture else None
    Handler.live_project = args.live_project
    Handler.request_limit = args.max_live_requests
    Handler.request_count = 0
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    mode = "live Google Vision" if args.live_project else "fixture"
    print(f"Dressed {mode} recognition service on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
