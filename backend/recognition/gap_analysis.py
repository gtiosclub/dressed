"""Find where the recognition flow loses pieces and flag ones needing more evidence.

This is the P18 gap analysis. It runs the existing object-localization adapter on
hard-case fixtures (layered outfits, partly hidden garments, small accessories,
cropped photos, difficult lighting) and, for every miss or false alert, attributes
the problem to the stage where the piece was lost:

- ``no-box``           the provider returned no region at all for the piece. There
                       is no visual clue, so Dressed must NOT name it and it is not
                       flagged as a possible missing piece.
- ``non-garment-label``  a region was returned but only under a generic label such
                       as Person or Clothing, so the label map cannot name a piece.
                       This is the "there may be a piece here" case (for example a
                       collar visible above a jacket).

A localized piece whose suggested category does not match the truth is recorded as
a ``categoryError`` (a false suggestion) rather than a missing piece. Only pieces
with a returned region (a genuine visual clue) appear in ``possibleMissing``. A
fully hidden piece with no box is a plain miss and is never given a name. This is a
fixture-driven contract check, not evidence of any provider's accuracy on real
photos.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from object_localization import LABELS, parse_response


IOU_THRESHOLD = 0.5


def _validated_truth(value: object) -> dict:
    if not isinstance(value, dict):
        raise ValueError("groundTruth item must be an object")
    valid = {mapped[1] for mapped in LABELS.values()} | {"other"}
    category = value.get("category")
    if category not in valid:
        raise ValueError(f"unknown Dressed category {category!r}")
    box = value.get("boundingBox")
    if not isinstance(box, dict):
        raise ValueError("groundTruth item needs boundingBox")
    coords = [box.get(key) for key in ("x", "y", "width", "height")]
    if any(not isinstance(number, (int, float)) or isinstance(number, bool)
           for number in coords):
        raise ValueError("boundingBox needs numeric x, y, width, height")
    x, y, width, height = coords
    if not (0 <= x < 1 and 0 <= y < 1 and 0 < width <= 1 - x
            and 0 < height <= 1 - y):
        raise ValueError("boundingBox must fit within normalized image coordinates")
    return {"category": category, "boundingBox": box}


def _intersection_over_union(first: dict, second: dict) -> float:
    left = max(first["x"], second["x"])
    top = max(first["y"], second["y"])
    right = min(first["x"] + first["width"], second["x"] + second["width"])
    bottom = min(first["y"] + first["height"], second["y"] + second["height"])
    overlap = max(0, right - left) * max(0, bottom - top)
    union = first["width"] * first["height"] + second["width"] * second["height"] - overlap
    return overlap / union if union else 0


def _raw_annotations(response: object) -> list[dict]:
    """Flatten localizedObjectAnnotations to (label, box, score) without mapping."""
    if (not isinstance(response, dict)
            or not isinstance(response.get("responses"), list)
            or not response["responses"]
            or not isinstance(response["responses"][0], dict)):
        raise ValueError("expected one Vision annotation response")
    annotation = response["responses"][0]
    if "error" in annotation:
        raise ValueError("Vision error in response")
    objects = annotation.get("localizedObjectAnnotations", [])
    if not isinstance(objects, list):
        raise ValueError("invalid localizedObjectAnnotations")
    found = []
    for obj in objects:
        if not isinstance(obj, dict) or not isinstance(obj.get("name"), str):
            continue
        label = obj["name"].strip().lower()
        score = obj.get("score")
        box = None
        vertices = obj.get("boundingPoly", {}).get("normalizedVertices")
        if isinstance(vertices, list) and vertices:
            points = [(v.get("x", 0), v.get("y", 0)) for v in vertices if isinstance(v, dict)]
            if len(points) >= 2:
                xs = [x for x, _ in points]
                ys = [y for _, y in points]
                left, right = min(xs), max(xs)
                top, bottom = min(ys), max(ys)
                if (isinstance(score, (int, float)) and not isinstance(score, bool)
                        and right - left >= 0.01 and bottom - top >= 0.01):
                    box = {"x": left, "y": top, "width": right - left, "height": bottom - top}
        if box is not None:
            found.append({"label": label, "box": box, "score": score})
    return found


def _analyze_sample(response: object, sample: object, import_id: str) -> dict:
    truth = [_validated_truth(item) for item in sample["groundTruth"]]
    raw = _raw_annotations(response)
    predictions = parse_response(response, import_id)["candidates"]

    def overlaps(prediction: dict, expected: dict) -> bool:
        return _intersection_over_union(expected["boundingBox"], prediction["boundingBox"]) >= IOU_THRESHOLD

    missed: list[dict] = []
    possible_missing: list[dict] = []
    localized: list[dict] = []
    for expected in truth:
        matched = [found for found in predictions if overlaps(found, expected)]
        if matched:
            best_match = max(matched, key=lambda found: _intersection_over_union(
                expected["boundingBox"], found["boundingBox"]))
            localized.append({"piece": expected["category"], "name": best_match["suggestedName"],
                              "categoryCorrect": best_match["suggestedCategory"] == expected["category"]})
            continue
        # Not localized by a confirmed candidate. Look for any raw region
        # overlapping the expected piece: that region is the visual clue that
        # justifies a "possible missing piece".
        best = max(((r, _intersection_over_union(expected["boundingBox"], r["box"]))
                    for r in raw), key=lambda pair: pair[1], default=(None, 0.0))
        raw_region, overlap = best
        if raw_region is None or overlap < IOU_THRESHOLD:
            # No region at all: no visual clue, so never name this piece.
            missed.append({"piece": expected["category"], "stage": "no-box", "clue": False})
            continue
        stage = "non-garment-label"
        missed.append({"piece": expected["category"], "stage": stage, "clue": True})
        possible_missing.append({"piece": expected["category"], "clueLabel": raw_region["label"],
                                 "reason": f"A region is visible but only as “{raw_region['label']}”, so it cannot be named.",
                                 "stage": stage})

    # Confirmed predictions that matched nothing in the truth are false alerts.
    false_alerts = [{"name": found["suggestedName"], "category": found["suggestedCategory"],
                     "stage": "false-detection"}
                    for found in predictions if not any(overlaps(found, expected) for expected in truth)]

    before = {"truth": [item["category"] for item in truth],
              "predictions": [item["suggestedCategory"] for item in predictions]}
    after = {"localized": localized, "missed": missed, "falseAlerts": false_alerts}
    return {"importId": import_id, "before": before, "after": after,
            "possibleMissing": possible_missing}


def analyze(manifest: object, manifest_directory: Path,
            provider: str = "object-localization") -> dict:
    if provider != "object-localization":
        raise ValueError("gap analysis supports only object-localization fixtures today")
    if (not isinstance(manifest, dict)
            or not isinstance(manifest.get("samples"), list)
            or not manifest["samples"]):
        raise ValueError("manifest needs a nonempty samples array")

    samples = []
    totals = {"samples": 0, "truthPieces": 0, "detected": 0, "missed": 0,
              "categoryErrors": 0, "falseAlerts": 0, "possibleMissing": 0}
    stage_counts: dict[str, int] = {}

    for raw in manifest["samples"]:
        if (not isinstance(raw, dict)
                or not isinstance(raw.get("importId"), str)
                or not isinstance(raw.get("responseFile"), str)
                or not isinstance(raw.get("groundTruth"), list)):
            raise ValueError("each sample needs importId, responseFile, and groundTruth")
        response = json.loads((manifest_directory / raw["responseFile"]).read_text())
        result = _analyze_sample(response, raw, raw["importId"])
        samples.append(result)
        totals["samples"] += 1
        totals["truthPieces"] += len(result["before"]["truth"])
        totals["detected"] += len(result["after"]["localized"])
        totals["categoryErrors"] += sum(1 for item in result["after"]["localized"]
                                       if not item["categoryCorrect"])
        for miss in result["after"]["missed"]:
            totals["missed"] += 1
            stage_counts[miss["stage"]] = stage_counts.get(miss["stage"], 0) + 1
        totals["falseAlerts"] += len(result["after"]["falseAlerts"])
        totals["possibleMissing"] += len(result["possibleMissing"])

    return {"provider": provider, "samples": samples, "totals": totals,
            "stageCounts": stage_counts}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text())
        print(json.dumps(analyze(manifest, args.manifest.parent), indent=2))
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"gap analysis error: {error}\n")


if __name__ == "__main__":
    main()
