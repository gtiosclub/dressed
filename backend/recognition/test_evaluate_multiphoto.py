import copy
import json
import unittest
from pathlib import Path

from evaluate_multiphoto import evaluate, first_photo_baseline, score_outfit


FIXTURES = Path(__file__).parent / "fixtures" / "multiphoto"


def box(x, y, width=0.2, height=0.2):
    return {"x": x, "y": y, "width": width, "height": height}


class MultiPhotoEvaluationTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((FIXTURES / "manifest.json").read_text())
        self.result = evaluate(self.manifest, FIXTURES)

    def test_outfit_counts_coverage_duplicates_and_wrong_groupings(self):
        multi = self.result["outfit"]["in-house:multiPhoto"]
        self.assertEqual(multi["trueGarments"], 3)
        self.assertEqual(multi["found"], 3)
        self.assertEqual(multi["missed"], 0)
        # Jeans were split into two candidates: one duplicate, one wrong grouping.
        self.assertEqual(multi["duplicates"], 1)
        self.assertEqual(multi["garmentsInTwoOrMorePhotos"], 2)
        self.assertEqual(multi["wronglyGrouped"], 1)
        self.assertAlmostEqual(multi["duplicateRate"], 1 / 3)
        self.assertFalse(multi["meetsProposedDuplicateLimit"])
        self.assertEqual(multi["categoryAccuracyOnFound"], 1)

    def test_first_photo_baseline_misses_piece_only_visible_later(self):
        baseline = self.result["outfit"]["in-house:firstPhotoOnly"]
        self.assertEqual(baseline["found"], 2)
        self.assertEqual(baseline["missed"], 1)
        self.assertEqual(baseline["duplicates"], 0)
        self.assertTrue(self.result["outfit"]["in-house:multiPhoto"]["foundMoreThanFirstPhoto"])

    def test_one_item_compares_combined_first_and_best_single_guess(self):
        summary = self.result["oneItem"]["in-house"]
        self.assertEqual(summary["imports"], 2)
        self.assertEqual(summary["combinedCategoryAccuracy"], 1)
        # Jacket's first photo guessed Shirt; the sweater's first photo was right.
        self.assertEqual(summary["firstPhotoCategoryAccuracy"], 0.5)
        self.assertEqual(summary["bestSinglePhotoCategoryAccuracy"], 1)
        self.assertTrue(summary["combinedBeatsFirstPhoto"])
        self.assertTrue(summary["combinedMatchesBestSinglePhoto"])

    def test_first_photo_follows_manifest_order_not_sighting_order(self):
        jacket = next(i for i in self.result["imports"]
                      if i["importId"] == "synthetic-jacket-front-back")
        self.assertEqual(jacket["methods"]["in-house"]["firstPhoto"], (False, False))

    def test_wrong_merge_of_two_garments_is_counted(self):
        garments = [
            {"category": "tops", "name": "Shirt", "sightings": {"a": box(0, 0), "b": box(0, 0)}},
            {"category": "tops", "name": "Tee", "sightings": {"a": box(0.5, 0.5), "b": box(0.5, 0.5)}},
        ]
        merged = [{"category": "tops", "name": "Shirt", "sightings": [
            {"photoId": "a", "boundingBox": box(0, 0)},
            {"photoId": "b", "boundingBox": box(0.5, 0.5)},
        ]}]
        scores = score_outfit(garments, merged)
        self.assertEqual(scores["wrongMergeCandidates"], 1)
        self.assertEqual(scores["wronglyGrouped"], 2)
        self.assertEqual(scores["duplicates"], 0)

    def test_unmatched_and_boxless_sightings_count_as_extra(self):
        garments = [{"category": "shoes", "name": "Shoes", "sightings": {"a": box(0.1, 0.7)}}]
        predicted = [
            {"category": "shoes", "name": "Shoes", "sightings": [{"photoId": "a", "boundingBox": box(0.6, 0.1)}]},
            {"category": "other", "name": "Piece", "sightings": [{"photoId": "a"}]},
        ]
        scores = score_outfit(garments, predicted)
        self.assertEqual(scores["found"], 0)
        self.assertEqual(scores["extraCandidates"], 2)
        self.assertEqual(first_photo_baseline(predicted, "a")[1]["name"], "Piece")

    def test_cost_is_summed_per_method(self):
        self.assertEqual(self.result["cost"]["in-house"]["imports"], 3)
        self.assertEqual(self.result["cost"]["in-house"]["visionCalls"], 7)
        self.assertEqual(self.result["cost"]["in-house"]["latencyMs"], 2400)

    def test_rejects_bad_manifests(self):
        bad = copy.deepcopy(self.manifest)
        bad["imports"][1]["garments"].append(bad["imports"][1]["garments"][0])
        with self.assertRaisesRegex(ValueError, "exactly one garment"):
            evaluate(bad, FIXTURES)
        bad = copy.deepcopy(self.manifest)
        bad["imports"][0]["garments"][0]["sightings"][0]["photoId"] = "missing"
        with self.assertRaisesRegex(ValueError, "not in photos"):
            evaluate(bad, FIXTURES)
        bad = copy.deepcopy(self.manifest)
        bad["imports"][0]["garments"][0]["sightings"][0]["boundingBox"]["width"] = 2
        with self.assertRaisesRegex(ValueError, "normalized"):
            evaluate(bad, FIXTURES)


if __name__ == "__main__":
    unittest.main()
