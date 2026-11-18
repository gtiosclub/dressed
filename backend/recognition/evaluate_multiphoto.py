"""Score multi-photo import results against manually annotated garments (issue #210).

Method-agnostic: each import lists one predictions file per method (for example
"in-house" from the app's grouper, or "joint" from evaluate_joint.py). A
predictions file holds the grouped candidates that method produced, each with
the per-photo sightings it is based on. The one-photo baseline is derived from
the same output: every sighting in the first photo, treated as its own piece,
is what a single-photo import of that photo would have shown.

Thresholds below are the proposal's proposed values and need lead sign-off.
Developer-only: reads saved JSON, makes no network calls, writes nothing.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from evaluate import IOU_THRESHOLD, VALID_CATEGORIES, intersection_over_union, validated_box


PROPOSED_MAX_DUPLICATE_RATE = 0.05
PROPOSED_MAX_WRONG_GROUPING_RATE = 0.10
MODES = {"oneItem", "oneOutfit"}


def normalized_name(name: object) -> str:
    if not isinstance(name, str):
        return ""
    return " ".join(re.findall(r"[a-z0-9]+", name.lower()))


def _rate(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def _validated_sighting(raw: object, photo_ids: set[str], where: str) -> dict:
    if not isinstance(raw, dict) or raw.get("photoId") not in photo_ids:
        raise ValueError(f"{where}: each sighting needs a photoId listed in photos")
    sighting = {"photoId": raw["photoId"]}
    if raw.get("boundingBox") is not None:
        sighting["boundingBox"] = validated_box(raw["boundingBox"])
    for key in ("category", "name"):
        if key in raw:
            sighting[key] = raw[key]
    if isinstance(raw.get("confidence"), (int, float)) and not isinstance(raw["confidence"], bool):
        sighting["confidence"] = float(raw["confidence"])
    return sighting


def _load_predictions(path: Path, photo_ids: set[str]) -> dict:
    raw = json.loads(path.read_text())
    if not isinstance(raw, dict) or not isinstance(raw.get("candidates"), list):
        raise ValueError(f"{path.name}: predictions need a candidates array")
    candidates = []
    for item in raw["candidates"]:
        if not isinstance(item, dict) or not isinstance(item.get("sightings"), list):
            raise ValueError(f"{path.name}: each candidate needs a sightings array")
        candidates.append({
            "category": item.get("category"),
            "name": item.get("name", ""),
            "sightings": [_validated_sighting(s, photo_ids, path.name) for s in item["sightings"]],
        })
    cost = {key: raw[key] for key in ("latencyMs", "visionCalls", "modelCalls", "photosAnalyzed") if key in raw}
    return {"candidates": candidates, "cost": cost}


def _match_sightings(garments: list[dict], candidates: list[dict]) -> dict[tuple[int, int], int]:
    """Greedy IoU matching per photo: (candidate, sighting) -> garment index."""
    pairs = []
    for c_index, candidate in enumerate(candidates):
        for s_index, sighting in enumerate(candidate["sightings"]):
            if "boundingBox" not in sighting:
                continue
            for g_index, garment in enumerate(garments):
                truth = garment["sightings"].get(sighting["photoId"])
                if truth is None:
                    continue
                overlap = intersection_over_union(truth, sighting["boundingBox"])
                if overlap >= IOU_THRESHOLD:
                    pairs.append((overlap, c_index, s_index, g_index, sighting["photoId"]))
    matches: dict[tuple[int, int], int] = {}
    used_truth: set[tuple[int, str]] = set()
    for _, c_index, s_index, g_index, photo_id in sorted(pairs, reverse=True):
        if (c_index, s_index) in matches or (g_index, photo_id) in used_truth:
            continue
        matches[(c_index, s_index)] = g_index
        used_truth.add((g_index, photo_id))
    return matches


def score_outfit(garments: list[dict], candidates: list[dict]) -> dict:
    matches = _match_sightings(garments, candidates)
    covering: dict[int, set[int]] = {g: set() for g in range(len(garments))}
    covered_by_candidate: dict[int, set[int]] = {c: set() for c in range(len(candidates))}
    for (c_index, _), g_index in matches.items():
        covering[g_index].add(c_index)
        covered_by_candidate[c_index].add(g_index)

    found = [g for g, cands in covering.items() if cands]
    duplicates = sum(len(cands) - 1 for cands in covering.values() if cands)
    extra = sum(1 for garms in covered_by_candidate.values() if not garms)
    wrong_merges = sum(1 for garms in covered_by_candidate.values() if len(garms) > 1)

    multi_view = [g for g, garment in enumerate(garments) if len(garment["sightings"]) >= 2]
    wrongly_grouped = [
        g for g in multi_view
        if len(covering[g]) > 1 or any(len(covered_by_candidate[c]) > 1 for c in covering[g])
    ]

    correct_category = 0
    for g in found:
        # The candidate holding most of this garment's sightings is what the person reviews.
        best = max(covering[g], key=lambda c: sum(
            1 for (ci, _), gi in matches.items() if ci == c and gi == g))
        if candidates[best]["category"] == garments[g]["category"]:
            correct_category += 1

    total = len(garments)
    return {
        "trueGarments": total,
        "candidates": len(candidates),
        "found": len(found),
        "missed": total - len(found),
        "duplicates": duplicates,
        "extraCandidates": extra,
        "wrongMergeCandidates": wrong_merges,
        "garmentsInTwoOrMorePhotos": len(multi_view),
        "wronglyGrouped": len(wrongly_grouped),
        "correctCategories": correct_category,
    }


def first_photo_baseline(candidates: list[dict], first_photo: str) -> list[dict]:
    return [
        {"category": s.get("category", c["category"]), "name": s.get("name", c["name"]),
         "sightings": [s]}
        for c in candidates for s in c["sightings"] if s["photoId"] == first_photo
    ]


def _guess_correct(guess: dict | None, garment: dict) -> tuple[bool, bool]:
    if guess is None:
        return False, False
    category_ok = guess.get("category") == garment["category"]
    name_ok = category_ok and normalized_name(guess.get("name")) == normalized_name(garment["name"])
    return category_ok, name_ok


def score_one_item(garment: dict, candidates: list[dict], photo_order: list[str]) -> dict:
    """Category/name correctness for the combined guess and single-photo guesses."""
    combined = candidates[0] if candidates else None
    per_photo: dict[str, dict] = {}
    for candidate in candidates:
        for sighting in candidate["sightings"]:
            per_photo.setdefault(sighting["photoId"], {
                "category": sighting.get("category"), "name": sighting.get("name"),
            })
    first = per_photo.get(photo_order[0])
    singles = [_guess_correct(per_photo.get(p), garment) for p in photo_order]
    # Best single photo is an oracle: the most correct guess any one photo gave.
    best_single = max(singles, key=lambda pair: (pair[0], pair[1]), default=(False, False))
    return {
        "combined": _guess_correct(combined, garment),
        "firstPhoto": _guess_correct(first, garment),
        "bestSinglePhoto": best_single,
        "candidates": len(candidates),
    }


def _validated_import(raw: object) -> dict:
    if (not isinstance(raw, dict) or not isinstance(raw.get("importId"), str)
            or raw.get("mode") not in MODES
            or not isinstance(raw.get("photos"), list) or not raw["photos"]
            or not isinstance(raw.get("garments"), list)
            or not isinstance(raw.get("predictions"), dict) or not raw["predictions"]):
        raise ValueError("each import needs importId, mode, photos, garments, and predictions")
    photo_order = []
    for photo in raw["photos"]:
        if not isinstance(photo, dict) or not isinstance(photo.get("photoId"), str):
            raise ValueError(f"{raw['importId']}: each photo needs a photoId")
        photo_order.append(photo["photoId"])
    if len(set(photo_order)) != len(photo_order):
        raise ValueError(f"{raw['importId']}: photoIds must be unique")
    garments = []
    for item in raw["garments"]:
        if (not isinstance(item, dict) or item.get("category") not in VALID_CATEGORIES
                or not isinstance(item.get("name"), str)
                or not isinstance(item.get("sightings"), list)):
            raise ValueError(f"{raw['importId']}: each garment needs category, name, and sightings")
        boxes = {}
        for sighting in item["sightings"]:
            if not isinstance(sighting, dict) or sighting.get("photoId") not in photo_order:
                raise ValueError(f"{raw['importId']}: garment sighting photoId not in photos")
            boxes[sighting["photoId"]] = validated_box(sighting.get("boundingBox"))
        garments.append({"category": item["category"], "name": item["name"], "sightings": boxes})
    if raw["mode"] == "oneItem" and len(garments) != 1:
        raise ValueError(f"{raw['importId']}: oneItem imports annotate exactly one garment")
    return {"importId": raw["importId"], "mode": raw["mode"], "photoOrder": photo_order,
            "garments": garments, "predictions": raw["predictions"]}


def _add(totals: dict, values: dict) -> None:
    for key, value in values.items():
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            totals[key] = totals.get(key, 0) + value


def _outfit_summary(totals: dict) -> dict:
    return {
        **totals,
        "recall": _rate(totals.get("found", 0), totals.get("trueGarments", 0)),
        "duplicateRate": _rate(totals.get("duplicates", 0), totals.get("trueGarments", 0)),
        "wrongGroupingRate": _rate(totals.get("wronglyGrouped", 0),
                                   totals.get("garmentsInTwoOrMorePhotos", 0)),
        "categoryAccuracyOnFound": _rate(totals.get("correctCategories", 0), totals.get("found", 0)),
    }


def evaluate(manifest: object, manifest_directory: Path) -> dict:
    if not isinstance(manifest, dict) or not isinstance(manifest.get("imports"), list) \
            or not manifest["imports"]:
        raise ValueError("manifest needs a nonempty imports array")

    outfit: dict[str, dict] = {}
    one_item: dict[str, dict] = {}
    cost: dict[str, dict] = {}
    per_import = []
    for raw in manifest["imports"]:
        entry = _validated_import(raw)
        photo_ids = set(entry["photoOrder"])
        result = {"importId": entry["importId"], "mode": entry["mode"], "methods": {}}
        for method, relative in entry["predictions"].items():
            if not isinstance(relative, str):
                raise ValueError(f"{entry['importId']}: predictions map method to a file path")
            loaded = _load_predictions(manifest_directory / relative, photo_ids)
            _add(cost.setdefault(method, {"imports": 0}), {"imports": 1, **loaded["cost"]})
            if entry["mode"] == "oneOutfit":
                scores = {"multiPhoto": score_outfit(entry["garments"], loaded["candidates"])}
                if method != "joint":
                    baseline = first_photo_baseline(loaded["candidates"], entry["photoOrder"][0])
                    scores["firstPhotoOnly"] = score_outfit(entry["garments"], baseline)
                for variant, values in scores.items():
                    _add(outfit.setdefault(f"{method}:{variant}", {}), values)
            else:
                scores = score_one_item(entry["garments"][0], loaded["candidates"],
                                        entry["photoOrder"])
                bucket = one_item.setdefault(method, {"imports": 0})
                bucket["imports"] += 1
                for guess in ("combined", "firstPhoto", "bestSinglePhoto"):
                    category_ok, name_ok = scores[guess]
                    bucket[f"{guess}CategoryCorrect"] = bucket.get(f"{guess}CategoryCorrect", 0) + category_ok
                    bucket[f"{guess}NameCorrect"] = bucket.get(f"{guess}NameCorrect", 0) + name_ok
            result["methods"][method] = scores
        per_import.append(result)

    outfit_summary = {key: _outfit_summary(values) for key, values in outfit.items()}
    for key, summary in outfit_summary.items():
        if key.endswith(":multiPhoto"):
            duplicate_rate, wrong_rate = summary["duplicateRate"], summary["wrongGroupingRate"]
            summary["meetsProposedDuplicateLimit"] = (
                None if duplicate_rate is None else duplicate_rate <= PROPOSED_MAX_DUPLICATE_RATE)
            summary["meetsProposedWrongGroupingLimit"] = (
                None if wrong_rate is None else wrong_rate <= PROPOSED_MAX_WRONG_GROUPING_RATE)
            baseline = outfit_summary.get(key.replace(":multiPhoto", ":firstPhotoOnly"))
            if baseline is not None:
                summary["foundMoreThanFirstPhoto"] = summary["found"] > baseline["found"]

    one_item_summary = {}
    for method, bucket in one_item.items():
        count = bucket["imports"]
        summary = {"imports": count}
        for guess in ("combined", "firstPhoto", "bestSinglePhoto"):
            summary[f"{guess}CategoryAccuracy"] = _rate(bucket[f"{guess}CategoryCorrect"], count)
            summary[f"{guess}NameAccuracy"] = _rate(bucket[f"{guess}NameCorrect"], count)
        summary["combinedBeatsFirstPhoto"] = (
            summary["combinedCategoryAccuracy"] > summary["firstPhotoCategoryAccuracy"])
        summary["combinedMatchesBestSinglePhoto"] = (
            summary["combinedCategoryAccuracy"] >= summary["bestSinglePhotoCategoryAccuracy"])
        one_item_summary[method] = summary

    return {
        "iouThreshold": IOU_THRESHOLD,
        "proposedLimits": {"maxDuplicateRate": PROPOSED_MAX_DUPLICATE_RATE,
                           "maxWrongGroupingRate": PROPOSED_MAX_WRONG_GROUPING_RATE},
        "outfit": outfit_summary,
        "oneItem": one_item_summary,
        "cost": cost,
        "imports": per_import,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text())
        print(json.dumps(evaluate(manifest, args.manifest.parent), indent=2))
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, f"evaluation error: {error}\n")


if __name__ == "__main__":
    main()
