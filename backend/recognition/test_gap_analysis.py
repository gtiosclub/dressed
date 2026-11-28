"""Unit tests for the P18 gap analysis."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from gap_analysis import analyze, _analyze_sample

FIXTURES = Path(__file__).parent / "fixtures"


def _load(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


class GapAnalysisTests(unittest.TestCase):
    def test_layered_outfit_flags_possible_top(self) -> None:
        response = _load("gap-layered-outfit.json")
        sample = {
            "importId": "layered-jacket-shirt",
            "groundTruth": [
                {"category": "outerwear", "boundingBox": {"x": 0.1, "y": 0.15, "width": 0.8, "height": 0.55}},
                {"category": "tops", "boundingBox": {"x": 0.35, "y": 0.08, "width": 0.3, "height": 0.14}},
            ],
        }
        result = _analyze_sample(response, sample, sample["importId"])
        localized = result["after"]["localized"]
        self.assertEqual([item["piece"] for item in localized], ["outerwear"])
        missed = result["after"]["missed"]
        self.assertEqual(len(missed), 1)
        self.assertEqual(missed[0]["piece"], "tops")
        self.assertEqual(missed[0]["stage"], "non-garment-label")
        self.assertTrue(missed[0]["clue"])
        self.assertEqual(len(result["possibleMissing"]), 1)
        self.assertEqual(result["possibleMissing"][0]["piece"], "tops")
        self.assertIn("cannot be named", result["possibleMissing"][0]["reason"])

    def test_hidden_piece_without_clue_is_not_flagged(self) -> None:
        response = _load("gap-cropped-hard-light.json")
        sample = {
            "importId": "cropped-hard-light",
            "groundTruth": [
                {"category": "pants", "boundingBox": {"x": 0.2, "y": 0.45, "width": 0.6, "height": 0.5}},
                {"category": "accessories", "boundingBox": {"x": 0.7, "y": 0.85, "width": 0.2, "height": 0.1}},
            ],
        }
        result = _analyze_sample(response, sample, sample["importId"])
        missed = result["after"]["missed"]
        accessories = next(item for item in missed if item["piece"] == "accessories")
        self.assertEqual(accessories["stage"], "no-box")
        self.assertFalse(accessories["clue"])
        # A fully hidden piece must never be surfaced as a possible missing piece.
        self.assertEqual(result["possibleMissing"], [])

    def test_manifest_totals_and_stage_counts(self) -> None:
        manifest = _load("gap-evaluation.json")
        result = analyze(manifest, FIXTURES)
        self.assertEqual(result["totals"]["samples"], 2)
        self.assertEqual(result["totals"]["truthPieces"], 5)
        self.assertEqual(result["totals"]["detected"], 2)
        self.assertEqual(result["totals"]["missed"], 3)
        self.assertEqual(result["totals"]["possibleMissing"], 2)
        self.assertEqual(result["stageCounts"], {"non-garment-label": 2, "no-box": 1})

    def test_whole_image_garment_region_is_not_flagged(self) -> None:
        # A whole-image Shirt box is ignored by the parser (cannot isolate a
        # garment) and overlaps any single piece at IoU < 0.5, so it is no usable
        # clue for a specific piece. It must not be flagged.
        response = {
            "responses": [
                {"localizedObjectAnnotations": [
                    {"name": "Shirt", "score": 0.8,
                     "boundingPoly": {"normalizedVertices": [
                         {"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 0.0},
                         {"x": 1.0, "y": 1.0}, {"x": 0.0, "y": 1.0}]}},
                ]},
            ],
        }
        sample = {
            "importId": "whole-image-shirt",
            "groundTruth": [{"category": "tops", "boundingBox": {"x": 0.1, "y": 0.1, "width": 0.6, "height": 0.5}}],
        }
        result = _analyze_sample(response, sample, sample["importId"])
        self.assertEqual(result["after"]["localized"], [])
        self.assertEqual(result["after"]["missed"][0]["stage"], "no-box")
        self.assertEqual(result["possibleMissing"], [])

    def test_invalid_manifest_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            analyze({"samples": []}, FIXTURES)
        with self.assertRaises(ValueError):
            analyze({"samples": [{"importId": "x"}]}, FIXTURES)
        with self.assertRaises(ValueError):
            analyze({"samples": [{"importId": "x", "responseFile": "gap-layered-outfit.json",
                                  "groundTruth": [{"category": "nonsense", "boundingBox": {}}]}]}, FIXTURES)


if __name__ == "__main__":
    unittest.main()
