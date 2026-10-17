"""Loopback-only development bridge from the iOS simulator to Google Vision.

Run explicitly with --live to allow charged requests. No photos or tokens are
persisted. This is not an authenticated production endpoint.
"""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from object_localization import parse_response
from product_search import MAX_IMAGE_BYTES, PAID_VISION_ENABLED, reserve_live_request


class Handler(BaseHTTPRequestHandler):
    fixture: dict | None = None
    live = False
    project = ""

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
            if self.fixture is not None:
                response = self.fixture
            elif self.live:
                token = subprocess.check_output(
                    ["gcloud", "auth", "print-access-token"], text=True, timeout=15
                ).strip()
                if not token:
                    raise RuntimeError("Google Cloud CLI is not signed in")
                reserve_live_request()
                body = json.dumps({"requests": [{
                    "image": {"content": base64.b64encode(image).decode("ascii")},
                    "features": [{"type": "OBJECT_LOCALIZATION"}],
                }]}).encode()
                request = Request(
                    "https://vision.googleapis.com/v1/images:annotate", data=body,
                    headers={"Authorization": f"Bearer {token}",
                             "Content-Type": "application/json",
                             "X-Goog-User-Project": self.project}, method="POST",
                )
                with urlopen(request, timeout=25) as result:
                    response = json.load(result)
            else:
                raise RuntimeError("service has no response source")
            result = parse_response(response, import_id)
            encoded = json.dumps(result).encode()
            self.send_response(200)
        except HTTPError as error:
            try:
                details = json.loads(error.read()).get("error", {})
                message = details.get("message", "Google Vision rejected the request")
            except (ValueError, AttributeError):
                message = "Google Vision rejected the request"
            encoded = json.dumps({"error": f"Google Vision: {message}"}).encode()
            self.send_response(400)
        except (ValueError, RuntimeError, subprocess.CalledProcessError,
                subprocess.TimeoutExpired, URLError) as error:
            # Never include provider tokens or image bytes in error responses.
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
    source.add_argument("--live", action="store_true")
    parser.add_argument("--project", help="explicit Google Cloud quota/billing project in live mode")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if args.live and not args.project:
        parser.error("--live requires --project")
    if args.live and not PAID_VISION_ENABLED:
        parser.error("paid Google Vision requests are paused: no enforceable spend cap")
    if args.fixture and args.project:
        parser.error("--project is only for live mode")
    Handler.fixture = json.loads(args.fixture.read_text()) if args.fixture else None
    Handler.live = args.live
    Handler.project = args.project or ""
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Dressed recognition test service on 127.0.0.1:{args.port} "
          f"({'live, at most 10 total reserved requests' if args.live else 'fixture'})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
