"""Bounded Google Product Search experiment for reviewed garment imports.

This is a developer CLI, not an app endpoint. It never writes closet records.
Live mode sends one explicitly selected image to Google Cloud Vision.
"""

from __future__ import annotations

import argparse
import base64
import fcntl
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "catalog"))
from catalog import CatalogDatabase  # noqa: E402
from object_localization import parse_response as parse_object_response


MAX_IMAGE_BYTES = 5_000_000
LIVE_REQUEST_LIMIT = 10
LIVE_REQUEST_LEDGER = Path.home() / ".local/state/dressed-recognition/live-requests.json"
# Cloud Vision has no project spend cap. Keep paid calls off until a separate,
# enforceable spending arrangement is in place; fixtures remain usable.
PAID_VISION_ENABLED = False
PRODUCT_SET = re.compile(r"^projects/[^/]+/locations/[^/]+/productSets/[^/]+$")
CATALOG_ID = re.compile(r"^[0-9a-f]{24}$")
CATEGORY_NAMES = {
    "tops": "Top", "pants": "Pants", "skirts": "Skirt", "dresses": "Dress",
    "shoes": "Shoes", "outerwear": "Outerwear", "accessories": "Accessory",
    "other": "Clothing item",
}


def _box(vertices: object) -> dict | None:
    if not isinstance(vertices, list) or len(vertices) < 2:
        return None
    try:
        xs = [float(vertex.get("x", 0)) for vertex in vertices]
        ys = [float(vertex.get("y", 0)) for vertex in vertices]
    except (AttributeError, TypeError, ValueError):
        return None
    if any(not 0 <= value <= 1 for value in xs + ys):
        return None
    left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
    if right - left < .01 or bottom - top < .01:
        return None
    return {"x": left, "y": top, "width": right - left, "height": bottom - top}


def _is_whole_image(box: dict) -> bool:
    return (box["x"] < .02 and box["y"] < .02
            and box["width"] > .96 and box["height"] > .96)


def parse_response(response: object, import_id: str, catalog: CatalogDatabase) -> dict:
    """Convert provider boxes to review candidates and approved catalog links.

    Product Search also returns whole-image matches. Those are not individual
    garments, so the review flow receives only localized regions.
    """
    if not import_id or not import_id.strip():
        raise ValueError("import_id is required")
    if (not isinstance(response, dict)
            or not isinstance(response.get("responses"), list)
            or len(response["responses"]) != 1
            or not isinstance(response["responses"][0], dict)):
        raise ValueError("expected one Vision annotation response")
    annotation = response["responses"][0]
    if "error" in annotation:
        message = annotation["error"].get("message", "Vision request failed")
        raise ValueError(f"Vision error: {message}")
    search = annotation.get("productSearchResults", {})
    groups = search.get("productGroupedResults", [])
    if not isinstance(groups, list):
        raise ValueError("invalid productGroupedResults")

    regions = []
    for group in groups:
        if not isinstance(group, dict):
            continue
        polygon = group.get("boundingPoly")
        box = _box(polygon.get("normalizedVertices") if isinstance(polygon, dict) else None)
        if box is None or _is_whole_image(box):
            continue
        regions.append((box, group.get("results", [])))
    regions.sort(key=lambda entry: (entry[0]["y"], entry[0]["x"]))

    candidates = []
    for index, (box, results) in enumerate(regions):
        matches = []
        seen = set()
        if isinstance(results, list):
            for result in results:
                if not isinstance(result, dict):
                    continue
                raw_product = result.get("product")
                product_ref = raw_product.get("name", "") if isinstance(raw_product, dict) else ""
                if not isinstance(product_ref, str):
                    continue
                product_id = product_ref.rsplit("/", 1)[-1]
                score = result.get("score")
                if (not CATALOG_ID.fullmatch(product_id) or product_id in seen
                        or not isinstance(score, (int, float)) or isinstance(score, bool)
                        or not 0 <= score <= 1):
                    continue
                product = catalog.get(product_id)
                if product is None or product["status"] != "active":
                    continue
                seen.add(product_id)
                matches.append({
                    "id": product_id, "title": product["title"],
                    "category": product["category"], "sourceName": product["sourceName"],
                    "productURL": product["productURL"], "imageURL": product["imageURL"],
                    "lastCheckedAt": product["lastCheckedAt"], "similarityScore": score,
                })
        matches.sort(key=lambda item: item["similarityScore"], reverse=True)
        top = matches[0] if matches else None
        category = top["category"] if top else "other"
        candidate_id = hashlib.sha256(f"{import_id}\0{index}".encode()).hexdigest()[:24]
        candidates.append({
            "id": candidate_id, "boundingBox": box,
            "suggestedName": CATEGORY_NAMES[category],
            "suggestedCategory": category,
            "similarProducts": matches[:3], "selected": False,
        })
    return {
        "importId": import_id, "provider": "google-product-search",
        "indexTime": search.get("indexTime"),
        "status": "review" if candidates else "noDetection",
        "candidates": candidates,
    }


def query_google(image: bytes, product_set: str, access_token: str,
                 include_object_localization: bool = False) -> dict:
    if not PAID_VISION_ENABLED:
        raise ValueError("paid Google Vision requests are paused: no enforceable spend cap")
    if not image or len(image) > MAX_IMAGE_BYTES:
        raise ValueError("image must be 1 byte to 5 MB")
    if not PRODUCT_SET.fullmatch(product_set):
        raise ValueError("invalid product set resource name")
    features = [{"type": "PRODUCT_SEARCH"}]
    if include_object_localization:
        features.append({"type": "OBJECT_LOCALIZATION"})
    body = json.dumps({"requests": [{
        "image": {"content": base64.b64encode(image).decode("ascii")},
        "features": features,
        "imageContext": {"productSearchParams": {
            "productSet": product_set, "productCategories": ["apparel-v2"]}},
    }]}).encode()
    request = Request(
        "https://vision.googleapis.com/v1/images:annotate", data=body,
        headers={"Authorization": f"Bearer {access_token}",
                 "Content-Type": "application/json"}, method="POST",
    )
    try:
        with urlopen(request, timeout=20) as provider_response:
            return json.load(provider_response)
    except (HTTPError, URLError) as error:
        raise RuntimeError(f"Vision request failed: {error}") from error


def adc_token() -> str:
    try:
        import google.auth
        from google.auth.transport.requests import Request as AuthRequest
    except ImportError as error:
        raise RuntimeError("live mode requires google-auth: python3 -m pip install google-auth") from error
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"])
    credentials.refresh(AuthRequest())
    return credentials.token


def reserve_live_request(ledger_path: Path = LIVE_REQUEST_LEDGER) -> int:
    """Reserve one of ten lifetime CLI calls before contacting Google.

    This local guard only covers this CLI. It is not a cloud billing limit.
    Reservations remain counted when a network request fails because Google
    may already have processed it.
    """
    if not PAID_VISION_ENABLED:
        raise ValueError("paid Google Vision requests are paused: no enforceable spend cap")
    ledger_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(ledger_path, os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(descriptor, "r+") as ledger:
        fcntl.flock(ledger, fcntl.LOCK_EX)
        contents = ledger.read()
        try:
            count = json.loads(contents)["reservedRequests"] if contents else 0
        except (json.JSONDecodeError, KeyError, TypeError) as error:
            raise ValueError("invalid live-request ledger; refusing a cloud call") from error
        if not isinstance(count, int) or isinstance(count, bool) or count < 0:
            raise ValueError("invalid live-request ledger; refusing a cloud call")
        if count >= LIVE_REQUEST_LIMIT:
            raise ValueError(f"local limit reached: {LIVE_REQUEST_LIMIT} live Vision requests")
        ledger.seek(0)
        json.dump({"reservedRequests": count + 1}, ledger)
        ledger.truncate()
        ledger.flush()
        os.fsync(ledger.fileno())
        return LIVE_REQUEST_LIMIT - count - 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="existing local catalog SQLite file")
    parser.add_argument("--import-id", required=True, help="stable private draft ID")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--response-file", type=Path, help="saved Vision JSON; no cloud call")
    source.add_argument("--image", type=Path, help="local image for one live Vision call")
    parser.add_argument("--product-set", help="Google Product Search resource for live mode")
    parser.add_argument("--compare-object-localization", action="store_true",
                        help="request and show generic object detections on the same image")
    parser.add_argument("--response-output", type=Path,
                        help="save the raw provider response for later evaluation; file must not exist")
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error("catalog database does not exist")
    if args.image and not args.product_set:
        parser.error("--image requires --product-set")
    if args.response_file and args.product_set:
        parser.error("--product-set is only for live mode")

    catalog = CatalogDatabase(args.db)
    try:
        if args.response_file:
            response = json.loads(args.response_file.read_text())
        else:
            if not PAID_VISION_ENABLED:
                raise ValueError("paid Google Vision requests are paused: no enforceable spend cap")
            image = args.image.read_bytes()
            if not image or len(image) > MAX_IMAGE_BYTES:
                raise ValueError("image must be 1 byte to 5 MB")
            token = adc_token()
            reserve_live_request()
            response = query_google(image, args.product_set, token,
                                    args.compare_object_localization)
        product_result = parse_response(response, args.import_id, catalog)
        result = ({"productSearch": product_result,
                   "objectLocalization": parse_object_response(response, args.import_id)}
                  if args.compare_object_localization else product_result)
        if args.response_output:
            with args.response_output.open("x") as output:
                json.dump(response, output, indent=2)
        print(json.dumps(result, indent=2))
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"recognition error: {error}\n")
    finally:
        catalog.close()


if __name__ == "__main__":
    main()
