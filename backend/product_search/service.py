"""Loopback-only SerpAPI bridge for the Debug iOS simulator. Standard library only."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import time
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit, urlunsplit
from urllib.request import Request, urlopen

MAX_IMAGE_BYTES = 500_000
MAX_RESPONSE_BYTES = 2_000_000


class SearchError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status


def public_url(value: object, allowed_hosts: set[str] | None = None) -> str | None:
    if not isinstance(value, str) or len(value) > 4096:
        return None
    try:
        parts = urlsplit(value)
        host = (parts.hostname or "").lower()
        if (parts.scheme != "https" or not host or parts.username or parts.password
                or parts.port not in (None, 443) or "." not in host
                or host.endswith((".local", ".localhost"))):
            return None
        try:
            ipaddress.ip_address(host)
            return None
        except ValueError:
            pass
        if allowed_hosts is not None and not any(
                host == item or host.endswith("." + item) for item in allowed_hosts):
            return None
        return urlunsplit(("https", parts.netloc.lower(), parts.path, parts.query, ""))
    except ValueError:
        return None


def normalize(response: dict, allowed_hosts: set[str]) -> list[dict]:
    if not isinstance(response, dict) or response.get("error"):
        raise SearchError(502, "Provider search failed.")
    metadata = response.get("search_metadata")
    if not isinstance(metadata, dict) or metadata.get("status") != "Success":
        raise SearchError(502, "Provider search did not complete.")
    hits = response.get("visual_matches", [])
    if not isinstance(hits, list):
        raise SearchError(502, "Invalid provider results.")
    results, seen = [], set()
    for hit in hits:
        if not isinstance(hit, dict):
            continue
        link = public_url(hit.get("link"), allowed_hosts)
        title = hit.get("title")
        if not link or not isinstance(title, str) or not title.strip() or link in seen:
            continue
        seen.add(link)
        price = hit.get("price")
        display_price = price.get("value") if isinstance(price, dict) else None
        results.append({
            "id": hashlib.sha256(link.encode()).hexdigest()[:24],
            "title": title.strip()[:300],
            # Attribute to the actual destination, not an unverified provider label.
            "source": urlsplit(link).hostname,
            "productURL": link,
            "imageURL": public_url(hit.get("thumbnail")) or public_url(hit.get("image")),
            "price": display_price[:80] if isinstance(display_price, str) else None,
        })
        if len(results) == 10:
            break
    return results


def provider_json(request: Request) -> dict:
    try:
        with urlopen(request, timeout=25) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise SearchError(502, "Provider response was too large.")
        value = json.loads(raw)
        if not isinstance(value, dict) or value.get("error"):
            raise SearchError(502, "Provider rejected the request. Check backend configuration.")
        return value
    except HTTPError as error:
        status = 429 if error.code == 429 else 502
        error.close()
        raise SearchError(status, "Provider unavailable. Check backend usage/configuration.") from None
    except (URLError, TimeoutError, ValueError):
        # Never return/log a URL containing the API key or provider's error body.
        raise SearchError(502, "Provider unavailable or invalid response.") from None


def search_lens(image: bytes, key: str) -> dict:
    boundary = "dressed-" + uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="api_key"\r\n\r\n{key}\r\n'
        f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="crop.jpg"\r\n'
        'Content-Type: image/jpeg\r\n\r\n'
    ).encode() + image + f"\r\n--{boundary}--\r\n".encode()
    upload = provider_json(Request("https://serpapi.com/image", data=body,
                                   headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}))
    image_id = upload.get("image_id")
    if not isinstance(image_id, str) or not image_id:
        raise SearchError(502, "Provider did not return an image ID.")
    query = urlencode({"engine": "google_lens", "type": "visual_matches",
                       "image_id": image_id, "api_key": key, "hl": "en"})
    return provider_json(Request("https://serpapi.com/search.json?" + query))


class SearchSession:
    """One local developer session; serialized requests make retry reuse deterministic."""

    def __init__(self, provider, allowed_hosts: set[str], limit: int = 20, fixture: bool = False):
        self.provider = provider
        self.allowed_hosts = allowed_hosts
        self.limit = limit
        self.fixture = fixture
        self.calls = 0
        self.cache = {}

    def search(self, request_id: str, image: bytes) -> dict:
        try:
            uuid.UUID(request_id)
        except (ValueError, AttributeError):
            raise SearchError(400, "X-Request-ID must be a UUID.") from None
        if not 0 < len(image) <= MAX_IMAGE_BYTES or not image.startswith(b"\xff\xd8\xff"):
            raise SearchError(400, "Expected a JPEG crop no larger than 500 KB.")
        digest = hashlib.sha256(image).hexdigest()
        now = time.monotonic()
        self.cache = {key: value for key, value in self.cache.items() if now - value[0] < 600}
        if request_id in self.cache:
            _, previous_digest, result = self.cache[request_id]
            if digest != previous_digest:
                raise SearchError(409, "Request ID was already used for another crop.")
            return result
        if self.calls >= self.limit:
            raise SearchError(429, "Development request limit reached.")
        self.calls += 1  # Reserve before I/O, including failed/ambiguous provider calls.
        result = {"requestId": request_id,
                  "provider": "Fixture — not live shopping results" if self.fixture else "SerpAPI / Google Lens",
                  "searchedAt": datetime.now(timezone.utc).isoformat(),
                  "matches": normalize(self.provider(image), self.allowed_hosts)}
        self.cache[request_id] = (now, digest, result)
        return result


def make_handler(session: SearchSession):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            self.connection.settimeout(10)
            try:
                # Reject browser requests and DNS-rebinding hosts. This is not user authentication.
                expected_host = f"127.0.0.1:{self.server.server_port}"
                if self.headers.get("Origin") is not None or self.headers.get("Host") != expected_host:
                    raise SearchError(403, "Local native clients only.")
                if self.path != "/product-search":
                    raise SearchError(404, "Unknown endpoint.")
                if self.headers.get("Content-Type") != "image/jpeg" or self.headers.get("Transfer-Encoding"):
                    raise SearchError(415, "Send a JPEG body with Content-Length.")
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= MAX_IMAGE_BYTES:
                    raise SearchError(413, "Crop exceeds the 500 KB limit or is empty.")
                image = self.rfile.read(size)
                if len(image) != size:
                    raise SearchError(400, "Incomplete image.")
                result = session.search(self.headers.get("X-Request-ID", ""), image)
                status = 200
            except SearchError as error:
                status, result = error.status, {"error": str(error)}
            except (ValueError, TimeoutError):
                status, result = 400, {"error": "Invalid or incomplete request."}
            encoded = json.dumps(result).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            try:
                self.wfile.write(encoded)
            except (BrokenPipeError, ConnectionResetError):
                pass  # The user dismissed the sheet; do not log private request details.

        def log_message(self, format, *args):
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fixture", type=Path)
    mode.add_argument("--live", action="store_true")
    parser.add_argument("--allowed-host", action="append", default=[])
    parser.add_argument("--max-requests", type=int, default=20)
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    if not 1 <= args.max_requests <= 100:
        parser.error("--max-requests must be 1...100")
    key = os.environ.get("SERPAPI_API_KEY", "")
    if args.live and (not key or not args.allowed_host):
        parser.error("Live mode needs SERPAPI_API_KEY and at least one --allowed-host retailer domain")
    if args.fixture:
        response = json.loads(args.fixture.read_text())
        provider = lambda image: response
    else:
        provider = lambda image: search_lens(image, key)
    hosts = {host.lower() for host in args.allowed_host} or {"shop.example"}
    session = SearchSession(provider, hosts, args.max_requests, bool(args.fixture))
    server = HTTPServer(("127.0.0.1", args.port), make_handler(session))
    print(f"Dressed product search: {'FIXTURE' if args.fixture else 'LIVE'}, "
          f"127.0.0.1:{args.port}, maximum {args.max_requests} attempts", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
