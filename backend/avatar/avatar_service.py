"""Loopback-only avatar try-on bridge for iOS simulator development.

The app sends the owner's reference photo and the outfit's piece photos. This
service adds the OpenAI key, calls the Images edit endpoint and returns the
generated image. The key never reaches the app.

    python3 backend/avatar/avatar_service.py --live          # paid OpenAI calls
    python3 backend/avatar/avatar_service.py --fixture x.png  # no key, no network
"""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

MAX_BODY_BYTES = 25_000_000
MAX_IMAGE_BYTES = 6_000_000
MAX_PIECES = 6
KEY_FILE = Path.home() / ".config/dressed/openai.env"
OPENAI_EDITS_URL = "https://api.openai.com/v1/images/edits"
DEFAULT_MODEL = "gpt-image-2.6-sunburst"

# Bump when the wording changes: the app stores it with each cached image.
PROMPT_VERSION = "v2"
STYLE_PROMPT = (
    "Stylized semi-realistic 3D character render of the person in image 1, like a polished video game "
    "avatar or character-creator portrait. Keep them clearly recognisable: same face shape, features, "
    "hairstyle, skin tone and body build. Render with smooth, softly simplified skin, clean sculpted "
    "forms, gently stylized proportions and soft subsurface lighting; it must not look like a photograph. "
    "Dress them in exactly the garments shown in the other images, keeping each garment's colour, cut, "
    "fit and print. Full body from head to shoes, standing relaxed and facing the camera, centred with a "
    "little space above the head and below the feet. Soft diffuse studio light on a clean, seamless, pale "
    "blue-grey to white background. If no shoes are given, use simple plain shoes that suit the outfit. "
    "No text, logos or watermarks except those printed on the garments."
)


class AvatarError(Exception):
    """An error with a stable code the app maps to user-facing text."""

    def __init__(self, code: str, message: str, status: int = 400):
        super().__init__(message)
        self.code = code
        self.status = status


def load_api_key(environ: dict | None = None, key_file: Path = KEY_FILE) -> str | None:
    environ = os.environ if environ is None else environ
    if environ.get("OPENAI_API_KEY"):
        return environ["OPENAI_API_KEY"].strip()
    if key_file.exists():
        for line in key_file.read_text().splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "OPENAI_API_KEY" and value.strip():
                return value.strip()
    return None


def decode_image(value: object, field: str) -> bytes:
    if not isinstance(value, str) or not value:
        raise AvatarError("invalid_request", f"{field} is missing")
    try:
        data = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError):
        raise AvatarError("invalid_request", f"{field} is not base64") from None
    if not data or len(data) > MAX_IMAGE_BYTES:
        raise AvatarError("invalid_request", f"{field} must be 1 byte to 6 MB")
    return data


def parse_request(body: dict) -> tuple[bytes, list[tuple[bytes, str]]]:
    """Returns the reference photo and (photo, label) pairs for each piece."""
    reference = decode_image(body.get("reference"), "reference")
    pieces = body.get("pieces")
    if not isinstance(pieces, list) or not pieces:
        raise AvatarError("invalid_request", "at least one piece is needed")
    if len(pieces) > MAX_PIECES:
        raise AvatarError("invalid_request", f"at most {MAX_PIECES} pieces")
    parsed = []
    for index, piece in enumerate(pieces):
        if not isinstance(piece, dict):
            raise AvatarError("invalid_request", "each piece must be an object")
        label = str(piece.get("label", "")).strip()[:80] or "garment"
        parsed.append((decode_image(piece.get("image"), f"pieces[{index}].image"), label))
    return reference, parsed


def build_prompt(labels: list[str]) -> str:
    lines = [f"Image {index + 2}: {label}." for index, label in enumerate(labels)]
    return STYLE_PROMPT + "\n\nImage 1: the person.\n" + "\n".join(lines)


def sniff_type(data: bytes) -> tuple[str, str]:
    if data.startswith(b"\x89PNG"):
        return "png", "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp", "image/webp"
    return "jpg", "image/jpeg"


def build_multipart(fields: dict[str, str], images: list[bytes]) -> tuple[bytes, str]:
    boundary = f"dressed-{uuid.uuid4().hex}"
    parts: list[bytes] = []
    for name, value in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
        )
    for index, data in enumerate(images):
        extension, content_type = sniff_type(data)
        parts.append(
            (f'--{boundary}\r\nContent-Disposition: form-data; name="image[]"; '
             f'filename="image{index}.{extension}"\r\nContent-Type: {content_type}\r\n\r\n').encode()
            + data + b"\r\n"
        )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def map_openai_error(status: int, payload: bytes) -> AvatarError:
    try:
        error = json.loads(payload).get("error", {})
    except (ValueError, AttributeError):
        error = {}
    code = str(error.get("code") or "")
    if status == 429:
        return AvatarError("rate_limited", "OpenAI rate limit or quota reached", 429)
    if status in (401, 403):
        return AvatarError("auth", "OpenAI rejected the API key", 502)
    if code == "moderation_blocked" or "safety" in code:
        return AvatarError("content_policy", "OpenAI declined to generate this image", 422)
    return AvatarError("upstream", f"OpenAI error {status}: {error.get('message', 'unknown')[:200]}", 502)


def generate_with_openai(api_key: str, model: str, quality: str, reference: bytes,
                         pieces: list[tuple[bytes, str]], timeout: float = 180) -> bytes:
    fields = {
        "model": model,
        "prompt": build_prompt([label for _, label in pieces]),
        "size": "1024x1536",
        "quality": quality,
        "output_format": "jpeg",
        "output_compression": "90",
        "n": "1",
    }
    body, content_type = build_multipart(fields, [reference] + [data for data, _ in pieces])
    request = Request(OPENAI_EDITS_URL, data=body, method="POST", headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": content_type,
    })
    try:
        with urlopen(request, timeout=timeout) as response:
            result = json.load(response)
    except HTTPError as error:
        raise map_openai_error(error.code, error.read()) from None
    except (URLError, TimeoutError) as error:
        raise AvatarError("upstream", f"could not reach OpenAI: {error}", 504) from None
    try:
        return base64.b64decode(result["data"][0]["b64_json"])
    except (KeyError, IndexError, TypeError, binascii.Error):
        raise AvatarError("upstream", "OpenAI returned no image", 502) from None


class Handler(BaseHTTPRequestHandler):
    api_key: str | None = None
    model = DEFAULT_MODEL
    quality = "medium"
    fixture: bytes | None = None
    fixture_delay = 2.0
    request_limit = 25
    request_count = 0
    request_lock = Lock()

    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_error(404)
            return
        mode = "live" if self.api_key else "fixture"
        self.reply(200, {"ok": True, "mode": mode, "model": self.model,
                         "promptVersion": PROMPT_VERSION,
                         "remaining": max(0, self.request_limit - self.request_count)})

    def do_POST(self) -> None:
        if self.path != "/avatar":
            self.send_error(404)
            return
        started = time.monotonic()
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size <= 0 or size > MAX_BODY_BYTES:
                raise AvatarError("invalid_request", "body must be 1 byte to 25 MB")
            try:
                body = json.loads(self.rfile.read(size))
            except ValueError:
                raise AvatarError("invalid_request", "body is not JSON") from None
            if not isinstance(body, dict):
                raise AvatarError("invalid_request", "body must be an object")
            reference, pieces = parse_request(body)
            image = self.generate(reference, pieces)
            self.reply(200, {
                "image": base64.b64encode(image).decode(),
                "model": self.model if self.api_key else "fixture",
                "promptVersion": PROMPT_VERSION,
            })
            # Timing only: no IDs, labels or image data in the log.
            print(f"avatar: {len(pieces)} pieces in {time.monotonic() - started:.1f}s", flush=True)
        except AvatarError as error:
            print(f"avatar error: {error.code}", flush=True)
            self.reply(error.status, {"error": error.code, "message": str(error)})

    def generate(self, reference: bytes, pieces: list[tuple[bytes, str]]) -> bytes:
        if self.api_key:
            with self.request_lock:
                if self.request_count >= self.request_limit:
                    raise AvatarError("limit_reached",
                                      "this service's paid request limit is reached; restart after checking usage", 429)
                self.__class__.request_count += 1
            return generate_with_openai(self.api_key, self.model, self.quality, reference, pieces)
        if self.fixture is not None:
            time.sleep(self.fixture_delay)
            return self.fixture
        raise AvatarError("unavailable", "service has no image source", 503)

    def reply(self, status: int, payload: dict) -> None:
        encoded = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--live", action="store_true",
                        help=f"paid OpenAI calls; key from OPENAI_API_KEY or {KEY_FILE}")
    source.add_argument("--fixture", type=Path, help="return this image for every request")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    parser.add_argument("--max-requests", type=int, default=25,
                        help="maximum paid calls in this process (default: 25)")
    parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args()
    if not 1 <= args.max_requests <= 200:
        parser.error("--max-requests must be between 1 and 200")
    if args.live:
        Handler.api_key = load_api_key()
        if not Handler.api_key:
            parser.error(f"no key: set OPENAI_API_KEY or create {KEY_FILE}")
    else:
        Handler.fixture = args.fixture.read_bytes()
    Handler.model = args.model
    Handler.quality = args.quality
    Handler.request_limit = args.max_requests
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    mode = f"live OpenAI ({args.model}, {args.quality})" if args.live else "fixture"
    print(f"Dressed avatar service, {mode}, on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
