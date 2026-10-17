"""Offline Google Product Search response adapter for reviewed garment imports.

This developer CLI reads saved JSON only. It never calls Google or writes closet records.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "catalog"))
from catalog import CatalogDatabase  # noqa: E402
from object_localization import parse_response as parse_object_response


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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path, help="existing local catalog SQLite file")
    parser.add_argument("--import-id", required=True, help="stable private draft ID")
    parser.add_argument("--response-file", required=True, type=Path,
                        help="saved Vision JSON; no cloud call")
    parser.add_argument("--compare-object-localization", action="store_true",
                        help="show generic object detections in the same saved response")
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error("catalog database does not exist")
    catalog = CatalogDatabase(args.db)
    try:
        response = json.loads(args.response_file.read_text())
        product_result = parse_response(response, args.import_id, catalog)
        result = ({"productSearch": product_result,
                   "objectLocalization": parse_object_response(response, args.import_id)}
                  if args.compare_object_localization else product_result)
        print(json.dumps(result, indent=2))
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"recognition error: {error}\n")
    finally:
        catalog.close()


if __name__ == "__main__":
    main()
