"""Turn Google Vision Object Localization output into review-only garment candidates.

This adapter accepts saved provider responses. It does not send images, save
closet records, or claim that a detected region is an exact product.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


# Only labels that describe a garment become candidates. General labels such
# as Person and Clothing cannot identify a separate piece in an outfit.
LABELS = {
    "shirt": ("Shirt", "tops"),
    "t-shirt": ("T-shirt", "tops"),
    "top": ("Top", "tops"),
    "sweater": ("Sweater", "tops"),
    "pants": ("Pants", "pants"),
    "jeans": ("Jeans", "pants"),
    "skirt": ("Skirt", "skirts"),
    "dress": ("Dress", "dresses"),
    "shoe": ("Shoe", "shoes"),
    "footwear": ("Shoes", "shoes"),
    "jacket": ("Jacket", "outerwear"),
    "coat": ("Coat", "outerwear"),
    "hat": ("Hat", "accessories"),
    "handbag": ("Handbag", "accessories"),
    "bag": ("Bag", "accessories"),
    "scarf": ("Scarf", "accessories"),
    "belt": ("Belt", "accessories"),
}


def _bounding_box(value: object) -> dict | None:
    if not isinstance(value, dict) or not isinstance(value.get("normalizedVertices"), list):
        return None
    vertices = value["normalizedVertices"]
    if len(vertices) < 2:
        return None
    points = []
    for vertex in vertices:
        if not isinstance(vertex, dict):
            return None
        x, y = vertex.get("x", 0), vertex.get("y", 0)
        if (not isinstance(x, (int, float)) or isinstance(x, bool)
                or not isinstance(y, (int, float)) or isinstance(y, bool)
                or not math.isfinite(x) or not math.isfinite(y)
                or not 0 <= x <= 1 or not 0 <= y <= 1):
            return None
        points.append((x, y))
    left, right = min(x for x, _ in points), max(x for x, _ in points)
    top, bottom = min(y for _, y in points), max(y for _, y in points)
    if right - left < .01 or bottom - top < .01:
        return None
    if left < .02 and top < .02 and right > .98 and bottom > .98:
        return None
    return {"x": left, "y": top, "width": right - left, "height": bottom - top}


def _intersection_over_union(first: dict, second: dict) -> float:
    left = max(first["x"], second["x"])
    top = max(first["y"], second["y"])
    right = min(first["x"] + first["width"], second["x"] + second["width"])
    bottom = min(first["y"] + first["height"], second["y"] + second["height"])
    overlap = max(0, right - left) * max(0, bottom - top)
    area = first["width"] * first["height"] + second["width"] * second["height"] - overlap
    return overlap / area if area else 0


def _combine_pair_of_shoes(candidates: list[dict], import_id: str) -> list[dict]:
    shoes = [item for item in candidates if item["suggestedCategory"] == "shoes"]
    if len(shoes) != 2:
        return candidates
    first, second = shoes
    a, b = first["boundingBox"], second["boundingBox"]
    ax, ay = a["x"] + a["width"] / 2, a["y"] + a["height"] / 2
    bx, by = b["x"] + b["width"] / 2, b["y"] + b["height"] / 2
    # Pair only two nearby, comparably sized detections. Separate displayed
    # shoes or a photo containing multiple pairs stay separate for review.
    sizes_match = (0.45 <= a["width"] / b["width"] <= 2.2
                   and 0.45 <= a["height"] / b["height"] <= 2.2)
    nearby = (abs(ax - bx) <= 2.5 * max(a["width"], b["width"])
              and abs(ay - by) <= 1.5 * max(a["height"], b["height"]))
    if not sizes_match or not nearby:
        return candidates
    left, top = min(a["x"], b["x"]), min(a["y"], b["y"])
    right = max(a["x"] + a["width"], b["x"] + b["width"])
    bottom = max(a["y"] + a["height"], b["y"] + b["height"])
    pair_id = hashlib.sha256(
        f'{import_id}\0shoe-pair\0{",".join(sorted((first["id"], second["id"])))}'.encode()
    ).hexdigest()[:24]
    pair = {
        "id": pair_id,
        "boundingBox": {"x": left, "y": top, "width": right - left, "height": bottom - top},
        "suggestedName": "Shoes", "suggestedCategory": "shoes",
        "rawLabel": "Shoe pair", "confidence": min(first["confidence"], second["confidence"]),
        "selected": False,
    }
    return [item for item in candidates if item["suggestedCategory"] != "shoes"] + [pair]


def parse_response(response: object, import_id: str) -> dict:
    """Return unselected candidates with IDs stable across response ordering."""
    if not isinstance(import_id, str) or not import_id.strip():
        raise ValueError("import_id is required")
    if (not isinstance(response, dict) or not isinstance(response.get("responses"), list)
            or len(response["responses"]) != 1
            or not isinstance(response["responses"][0], dict)):
        raise ValueError("expected one Vision annotation response")
    annotation = response["responses"][0]
    if "error" in annotation:
        error = annotation["error"]
        message = error.get("message", "Vision request failed") if isinstance(error, dict) else "Vision request failed"
        raise ValueError(f"Vision error: {message}")
    objects = annotation.get("localizedObjectAnnotations", [])
    if not isinstance(objects, list):
        raise ValueError("invalid localizedObjectAnnotations")

    candidates = {}
    for obj in objects:
        if not isinstance(obj, dict) or not isinstance(obj.get("name"), str):
            continue
        label = obj["name"].strip().lower()
        mapped = LABELS.get(label)
        score = obj.get("score")
        box = _bounding_box(obj.get("boundingPoly"))
        if (mapped is None or box is None
                or not isinstance(score, (int, float)) or isinstance(score, bool)
                or not math.isfinite(score) or not 0 <= score <= 1):
            continue
        # Quantization absorbs tiny serialization differences while retaining
        # the location as part of the candidate identity.
        location = ",".join(f"{box[key]:.4f}" for key in ("x", "y", "width", "height"))
        candidate_id = hashlib.sha256(f"{import_id}\0{label}\0{location}".encode()).hexdigest()[:24]
        candidate = {
            "id": candidate_id, "boundingBox": box,
            "suggestedName": mapped[0], "suggestedCategory": mapped[1],
            "rawLabel": obj["name"], "confidence": score, "selected": False,
        }
        previous = candidates.get(candidate_id)
        if previous is None or score > previous["confidence"]:
            candidates[candidate_id] = candidate
    filtered = []
    for candidate in sorted(candidates.values(), key=lambda item: -item["confidence"]):
        if any(candidate["suggestedCategory"] == prior["suggestedCategory"]
               and _intersection_over_union(candidate["boundingBox"], prior["boundingBox"]) >= .75
               for prior in filtered):
            continue
        filtered.append(candidate)
    filtered = _combine_pair_of_shoes(filtered, import_id)
    ordered = sorted(filtered, key=lambda item: (
        item["boundingBox"]["y"], item["boundingBox"]["x"], item["id"]))
    return {
        "importId": import_id, "provider": "google-object-localization",
        "status": "review" if ordered else "noDetection", "candidates": ordered,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-id", required=True)
    parser.add_argument("--response-file", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(parse_response(json.loads(args.response_file.read_text()), args.import_id), indent=2))
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"recognition error: {error}\n")


if __name__ == "__main__":
    main()
