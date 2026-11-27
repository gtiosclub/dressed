"""Score clothes parsing against hand-annotated development photos.

Manifest: {"samples": [{"image": "relative/path.jpg", "expected": ["top", "pants"],
"optional": ["shoes"]}]}. Labels are top, dress, pants, skirt, shoes and accessory
(hat, scarf, bag, sunglasses or belt). "optional" pieces are barely visible and are
neither required nor counted as extra. Use only photos you may use for development.

    python3 backend/recognition/evaluate_parser.py manifest.json ClothesParser.mlpackage
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path

from local_service import build_apple_vision, run_apple_vision

GARMENTS = ("top", "dress", "pants", "skirt")
ACCESSORIES = {"hat", "scarf", "bag", "sunglasses", "belt"}
LABELS = GARMENTS + ("shoes", "accessory")
GATE = 0.9


def label_for(part: str) -> str:
    return "accessory" if part in ACCESSORIES else part


def score(samples: list[dict], found: list[set[str]]) -> dict:
    expected, hits, extra = Counter(), Counter(), Counter()
    misses = []
    for sample, pieces in zip(samples, found):
        wanted = set(sample["expected"])
        optional = set(sample.get("optional", []))
        unknown = (wanted | optional) - set(LABELS)
        if unknown:
            raise ValueError(f"unknown labels: {sorted(unknown)}")
        for label in wanted:
            expected[label] += 1
            if label in pieces:
                hits[label] += 1
            else:
                misses.append({"image": sample["image"], "missed": label,
                               "found": sorted(pieces)})
        extra.update(pieces - wanted - optional)
    by_label = {label: {"found": hits[label], "expected": expected[label]}
                for label in LABELS if expected[label]}
    garment_total = sum(expected[label] for label in GARMENTS)
    garment_recall = (sum(hits[label] for label in GARMENTS) / garment_total
                      if garment_total else None)
    return {"photos": len(samples), "byLabel": by_label, "garmentRecall": garment_recall,
            "gatePassed": garment_recall is not None and all(
                hits[label] >= GATE * expected[label] for label in GARMENTS),
            "extra": dict(extra), "misses": misses}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("model", type=Path)
    args = parser.parse_args()
    samples = json.loads(args.manifest.read_text())["samples"]
    with tempfile.TemporaryDirectory() as directory:
        binary = build_apple_vision(Path(directory))
        found = []
        for index, sample in enumerate(samples):
            image = (args.manifest.parent / sample["image"]).read_bytes()
            result = run_apple_vision(binary, image, str(index), args.model.resolve())
            # Body-region fallbacks have no mask and are not parsing results.
            found.append({label_for(c["id"]) for c in result["candidates"] if c.get("mask")})
    report = score(samples, found)
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["gatePassed"] else 1)


if __name__ == "__main__":
    main()
