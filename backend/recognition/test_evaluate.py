import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "catalog"))
from catalog import CatalogDatabase
from evaluate import evaluate, intersection_over_union


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.catalog = CatalogDatabase(Path(self.temp.name) / "catalog.sqlite")
        self.catalog.ingest(json.loads((ROOT / "catalog/fixtures/demo-feed.json").read_text()))
        self.fixtures = Path(__file__).parent / "fixtures"
        self.manifest = json.loads((self.fixtures / "evaluation-example.json").read_text())

    def tearDown(self):
        self.catalog.close()
        self.temp.cleanup()

    def test_example_counts_detected_and_missed_garments(self):
        result = evaluate(self.manifest, self.fixtures, self.catalog)
        self.assertEqual(result["totals"]["truePositives"], 2)
        self.assertEqual(result["totals"]["falsePositives"], 0)
        self.assertEqual(result["totals"]["falseNegatives"], 1)
        self.assertEqual(result["localizationPrecision"], 1)
        self.assertAlmostEqual(result["localizationRecall"], 2 / 3)
        self.assertEqual(result["categoryAccuracyOnLocalized"], 1)
        self.assertEqual(result["byCategory"]["shoes"]["localized"], 0)

    def test_empty_detection_and_bad_annotations(self):
        empty = Path(self.temp.name) / "empty.json"
        empty.write_text('{"responses":[{"productSearchResults":{"productGroupedResults":[]}}]}')
        manifest = copy.deepcopy(self.manifest)
        manifest["samples"][0]["responseFile"] = str(empty)
        result = evaluate(manifest, self.fixtures, self.catalog)
        self.assertEqual(result["totals"]["imagesWithMissedAll"], 1)
        self.assertEqual(result["totals"]["falseNegatives"], 3)
        self.assertIsNone(result["localizationPrecision"])
        with self.assertRaisesRegex(ValueError, "normalized"):
            manifest["samples"][0]["groundTruth"][0]["boundingBox"]["width"] = 2
            evaluate(manifest, self.fixtures, self.catalog)

    def test_iou_of_disjoint_and_identical_boxes(self):
        first = {"x": 0, "y": 0, "width": .2, "height": .2}
        second = {"x": .8, "y": .8, "width": .2, "height": .2}
        self.assertEqual(intersection_over_union(first, first), 1)
        self.assertEqual(intersection_over_union(first, second), 0)


if __name__ == "__main__":
    unittest.main()
