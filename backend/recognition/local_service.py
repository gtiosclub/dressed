"""Loopback-only recognition bridge for iOS simulator development."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock

from google_vision import recognize
from object_localization import parse_response


MAX_IMAGE_BYTES = 5_000_000


class Handler(BaseHTTPRequestHandler):
    fixture: dict | None = None
    live_project: str | None = None
    apple_vision: Path | None = None
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
            if self.apple_vision:
                result = run_apple_vision(self.apple_vision, image, import_id)
            else:
                result = self.google_or_fixture_result(image, import_id)
            encoded = json.dumps(result).encode()
            self.send_response(200)
        except (ValueError, RuntimeError) as error:
            encoded = json.dumps({"error": str(error)}).encode()
            self.send_response(400)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def google_or_fixture_result(self, image: bytes, import_id: str) -> dict:
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
        # Optional demo hints for P18: a fixture may attach a "clues" list so
        # the app can show distinct "possible missing piece" states. This is a
        # synthetic contract check, not a provider result.
        clues = self.fixture.get("clues") if isinstance(self.fixture, dict) else None
        if isinstance(clues, list) and clues:
            result["possibleMissing"] = clues
        return result

    def log_message(self, format: str, *args: object) -> None:
        # HTTP logs could expose import IDs; this prototype prints only startup.
        pass


def build_apple_vision(directory: Path) -> Path:
    """Compile the Mac helper from the same region code the app uses."""
    root = Path(__file__).resolve().parents[2]
    binary = directory / "apple_vision"
    subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-O", "-o", str(binary),
                    str(root / "backend/recognition/apple_vision.swift"),
                    str(root / "dressed/Camera/ViewModels/GarmentPoseRegions.swift"),
                    str(root / "dressed/Common/Models/ImportSchema.swift"),
                    str(root / "dressed/Common/Models/ClothingSchema.swift")], check=True)
    return binary


def run_apple_vision(binary: Path, image: bytes, import_id: str) -> dict:
    with tempfile.NamedTemporaryFile() as photo:
        photo.write(image)
        photo.flush()
        done = subprocess.run([str(binary), photo.name, import_id], capture_output=True, timeout=30)
    if done.returncode != 0:
        raise RuntimeError("Apple Vision could not read this photo")
    return json.loads(done.stdout)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--fixture", type=Path)
    source.add_argument("--apple-vision", action="store_true",
                        help="detect pieces with Apple Vision on this Mac (no cloud calls)")
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
    if args.apple_vision:
        Handler.apple_vision = build_apple_vision(Path(tempfile.mkdtemp(prefix="dressed-vision-")))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    mode = "Apple Vision" if args.apple_vision else "live Google Vision" if args.live_project else "fixture"
    print(f"Dressed {mode} recognition service on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
