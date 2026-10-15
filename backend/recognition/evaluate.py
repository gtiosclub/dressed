"""Compare localized Product Search candidates with manually annotated garments."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from product_search import CatalogDatabase, parse_response


IOU_THRESHOLD = 0.5
VALID_CATEGORIES = {
    "tops", "pants", "skirts", "dresses", "shoes", "outerwear",
    "accessories", "other",
}


def validated_box(value: object) -> dict:
    if not isinstance(value, dict):
        raise ValueError("boundingBox must be an object")
    coords = [value.get(key) for key in ("x", "y", "width", "height")]
    if any(not isinstance(number, (int, float)) or isinstance(number, bool)
           for number in coords):
        raise ValueError("boundingBox needs numeric x, y, width, height")
    x, y, width, height = coords
    if not (0 <= x < 1 and 0 <= y < 1 and 0 < width <= 1 - x
            and 0 < height <= 1 - y):
        raise ValueError("boundingBox must fit within normalized image coordinates")
    return {"x": x, "y": y, "width": width, "height": height}


def intersection_over_union(a: dict, b: dict) -> float:
    left = max(a["x"], b["x"])
    top = max(a["y"], b["y"])
    right = min(a["x"] + a["width"], b["x"] + b["width"])
    bottom = min(a["y"] + a["height"], b["y"] + b["height"])
    intersection = max(0, right - left) * max(0, bottom - top)
    union = a["width"] * a["height"] + b["width"] * b["height"] - intersection
    return intersection / union if union else 0


def evaluate(manifest: object, manifest_directory: Path, catalog: CatalogDatabase) -> dict:
    if (not isinstance(manifest, dict)
            or not isinstance(manifest.get("samples"), list)
            or not manifest["samples"]):
        raise ValueError("manifest needs a nonempty samples array")
    totals = {"truePositives": 0, "falsePositives": 0, "falseNegatives": 0,
              "correctCategories": 0, "imagesWithMissedAll": 0}
    by_category: dict[str, dict[str, int]] = {}
    samples = []
    for raw in manifest["samples"]:
        if (not isinstance(raw, dict)
                or not isinstance(raw.get("importId"), str)
                or not isinstance(raw.get("responseFile"), str)
                or not isinstance(raw.get("groundTruth"), list)):
            raise ValueError("each sample needs importId, responseFile, and groundTruth")
        import_id = raw["importId"]
        response_path = manifest_directory / raw["responseFile"]
        parsed = parse_response(json.loads(response_path.read_text()), import_id, catalog)
        predictions = parsed["candidates"]
        truth = []
        for item in raw["groundTruth"]:
            if not isinstance(item, dict) or item.get("category") not in VALID_CATEGORIES:
                raise ValueError("groundTruth item needs a Dressed category")
            box = validated_box(item.get("boundingBox"))
            truth.append({"category": item["category"], "boundingBox": box})
            by_category.setdefault(item["category"], {"total": 0, "localized": 0,
                                                       "correctCategory": 0})["total"] += 1

        pairs = sorted(
            ((intersection_over_union(expected["boundingBox"], found["boundingBox"]), i, j)
             for i, expected in enumerate(truth)
             for j, found in enumerate(predictions)),
            reverse=True,
        )
        matched_truth: set[int] = set()
        matched_predictions: set[int] = set()
        correct_categories = 0
        for overlap, i, j in pairs:
            if overlap < IOU_THRESHOLD or i in matched_truth or j in matched_predictions:
                continue
            matched_truth.add(i)
            matched_predictions.add(j)
            category = truth[i]["category"]
            by_category[category]["localized"] += 1
            if predictions[j]["suggestedCategory"] == category:
                correct_categories += 1
                by_category[category]["correctCategory"] += 1

        true_positives = len(matched_truth)
        false_positives = len(predictions) - len(matched_predictions)
        false_negatives = len(truth) - true_positives
        totals["truePositives"] += true_positives
        totals["falsePositives"] += false_positives
        totals["falseNegatives"] += false_negatives
        totals["correctCategories"] += correct_categories
        if truth and not predictions:
            totals["imagesWithMissedAll"] += 1
        samples.append({"importId": import_id, "groundTruth": len(truth),
                        "predictions": len(predictions), "localized": true_positives,
                        "missed": false_negatives, "extra": false_positives,
                        "correctCategories": correct_categories})

    tp, fp, fn = (totals[key] for key in ("truePositives", "falsePositives", "falseNegatives"))
    return {
        "samples": samples, "totals": totals, "iouThreshold": IOU_THRESHOLD,
        "localizationPrecision": tp / (tp + fp) if tp + fp else None,
        "localizationRecall": tp / (tp + fn) if tp + fn else None,
        "categoryAccuracyOnLocalized": totals["correctCategories"] / tp if tp else None,
        "byCategory": by_category,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error("catalog database does not exist")
    catalog = CatalogDatabase(args.db)
    try:
        manifest = json.loads(args.manifest.read_text())
        print(json.dumps(evaluate(manifest, args.manifest.parent, catalog), indent=2))
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"evaluation error: {error}\n")
    finally:
        catalog.close()


if __name__ == "__main__":
    main()
