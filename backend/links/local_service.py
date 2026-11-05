"""Loopback-only product link import bridge for simulator development.

POST /product-imports {"url": ..., "clientRequestId": ...} -> draft.
The same clientRequestId returns the same draft, so retries create nothing new.
Page reading stays here; the iOS app never fetches store pages or holds keys.
"""

from __future__ import annotations

import argparse
import json
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock

from reader import normalize_url, read_product_link, UnsafeURL

MAX_BODY = 8_192
MAX_DRAFTS = 500


class Handler(BaseHTTPRequestHandler):
    fixture_html: str | None = None  # offline demo: serve this page for any link
    drafts: dict[str, dict] = {}
    lock = Lock()

    def _send(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        prefix = "/product-imports/"
        if self.path.startswith(prefix):
            with self.lock:
                for draft in self.drafts.values():
                    if draft["importId"] == self.path[len(prefix):]:
                        return self._send(200, draft)
        self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/product-imports":
            return self._send(404, {"error": "not found"})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BODY:
                raise ValueError("body must be 1 byte to 8 KB")
            body = json.loads(self.rfile.read(size))
            url, request_id = body.get("url"), body.get("clientRequestId")
            if not isinstance(url, str) or not isinstance(request_id, str) or not 0 < len(request_id) <= 100:
                raise ValueError("url and clientRequestId are required")
            normalize_url(url)
        except (ValueError, UnsafeURL, json.JSONDecodeError) as error:
            return self._send(400, {"error": str(error)})
        with self.lock:
            existing = self.drafts.get(request_id)
        if existing:
            return self._send(200, existing)
        fetcher = (lambda u, resolver=None: (200, u, self.fixture_html)) if self.fixture_html else None
        draft = (read_product_link(url, str(uuid.uuid4()), fetcher=fetcher) if fetcher
                 else read_product_link(url, str(uuid.uuid4())))
        with self.lock:
            if len(self.drafts) >= MAX_DRAFTS:
                self.drafts.pop(next(iter(self.drafts)))
            draft = self.drafts.setdefault(request_id, draft)
        self._send(200, draft)

    def log_message(self, format: str, *args: object) -> None:
        pass  # logs could expose product links


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8767)
    parser.add_argument("--fixture", type=Path, help="serve this saved HTML page for every link (no network)")
    args = parser.parse_args()
    if args.fixture:
        Handler.fixture_html = args.fixture.read_text()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Product link import on http://127.0.0.1:{args.port} (loopback only)")
    server.serve_forever()


if __name__ == "__main__":
    main()
