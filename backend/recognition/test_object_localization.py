import copy
import json
import unittest
from pathlib import Path

from evaluate import evaluate
from object_localization import parse_response


FIXTURES = Path(__file__).parent / "fixtures"


class ObjectLocalizationTests(unittest.TestCase):
    def setUp(self):
        self.response = json.loads((FIXTURES / "object-localization-response.json").read_text())

    def test_outfit_produces_two_unselected_garments_not_person(self):
        result = parse_response(self.response, "draft-1")
        self.assertEqual(result["status"], "review")
        self.assertEqual([c["suggestedCategory"] for c in result["candidates"]],
                         ["tops", "pants"])
        self.assertTrue(all(not c["selected"] for c in result["candidates"]))
        self.assertTrue(all("boundingBox" in c for c in result["candidates"]))

    def test_ids_survive_response_reordering_and_duplicate_boxes(self):
        first = parse_response(self.response, "draft-1")
        objects = self.response["responses"][0]["localizedObjectAnnotations"]
        objects.reverse()
        objects.append(copy.deepcopy(objects[1]))
        second = parse_response(self.response, "draft-1")
        self.assertEqual(second, first)
        self.assertNotEqual(parse_response(self.response, "draft-2")["candidates"][0]["id"],
                            first["candidates"][0]["id"])

    def test_two_nearby_shoes_become_one_review_piece(self):
        def shoe(left):
            return {"name": "Shoe", "score": 0.9, "boundingPoly": {"normalizedVertices": [
                {"x": left, "y": 0.7}, {"x": left + 0.12, "y": 0.7},
                {"x": left + 0.12, "y": 0.88}, {"x": left, "y": 0.88},
            ]}}
        response = {"responses": [{"localizedObjectAnnotations": [shoe(0.35), shoe(0.55)]}]}
        result = parse_response(response, "shoes")
        self.assertEqual(len(result["candidates"]), 1)
        self.assertEqual(result["candidates"][0]["suggestedName"], "Shoes")
        self.assertAlmostEqual(result["candidates"][0]["boundingBox"]["width"], 0.32)
        self.assertFalse(result["candidates"][0]["selected"])
        response["responses"][0]["localizedObjectAnnotations"].reverse()
        self.assertEqual(parse_response(response, "shoes"), result)

    def test_distant_shoes_stay_separate_for_review(self):
        response = {"responses": [{"localizedObjectAnnotations": [
            {"name": "Shoe", "score": 0.9, "boundingPoly": {"normalizedVertices": [
                {"x": left, "y": 0.7}, {"x": left + 0.1, "y": 0.7},
                {"x": left + 0.1, "y": 0.85}, {"x": left, "y": 0.85},
            ]}} for left in (0.1, 0.8)
        ]}]}
        self.assertEqual(len(parse_response(response, "distant")["candidates"]), 2)

    def test_no_garments_and_bad_boxes_keep_manual_fallback(self):
        objects = self.response["responses"][0]["localizedObjectAnnotations"]
        objects[1]["boundingPoly"]["normalizedVertices"][0]["x"] = 2
        objects[2]["score"] = float("nan")
        result = parse_response(self.response, "draft-1")
        self.assertEqual(result["status"], "noDetection")
        self.assertEqual(result["candidates"], [])

    def test_provider_failure_is_distinct_from_no_detection(self):
        with self.assertRaisesRegex(ValueError, "Vision error"):
            parse_response({"responses": [{"error": {"message": "quota"}}]}, "draft-1")
        with self.assertRaisesRegex(ValueError, "expected one"):
            parse_response({"responses": []}, "draft-1")

    def test_evaluation_reports_missed_shoe(self):
        manifest = json.loads((FIXTURES / "object-localization-evaluation.json").read_text())
        report = evaluate(manifest, FIXTURES, provider="object-localization")
        self.assertEqual(report["totals"]["truePositives"], 2)
        self.assertEqual(report["totals"]["falseNegatives"], 1)
        self.assertEqual(report["byCategory"]["shoes"]["localized"], 0)


if __name__ == "__main__":
    unittest.main()
