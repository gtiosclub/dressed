import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "catalog"))
from catalog import CatalogDatabase
from product_search import parse_response, query_google


class ProductSearchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.catalog = CatalogDatabase(Path(self.temp.name) / "catalog.sqlite")
        feed = json.loads((ROOT / "catalog/fixtures/demo-feed.json").read_text())
        self.catalog.ingest(feed)
        self.response = json.loads(
            (Path(__file__).parent / "fixtures/product-search-response.json").read_text())

    def tearDown(self):
        self.catalog.close()
        self.temp.cleanup()

    def test_two_regions_become_unselected_review_candidates_with_stable_ids(self):
        first = parse_response(self.response, "draft-1", self.catalog)
        again = parse_response(self.response, "draft-1", self.catalog)
        self.assertEqual(first, again)
        self.assertEqual(first["status"], "review")
        self.assertEqual(len(first["candidates"]), 2)
        self.assertEqual([item["suggestedCategory"] for item in first["candidates"]],
                         ["tops", "pants"])
        self.assertEqual(first["candidates"][0]["suggestedName"], "Top")
        self.assertTrue(all(not item["selected"] for item in first["candidates"]))
        self.assertEqual(first["candidates"][0]["similarProducts"][0]["title"],
                         "Blue cotton shirt")
        self.assertEqual(len(first["candidates"][0]["similarProducts"]), 1)
        self.assertNotEqual(first["candidates"][0]["id"], first["candidates"][1]["id"])

    def test_no_regions_keeps_manual_fallback_and_no_product_claim(self):
        self.response["responses"][0]["productSearchResults"]["productGroupedResults"] = []
        result = parse_response(self.response, "draft-1", self.catalog)
        self.assertEqual(result["status"], "noDetection")
        self.assertEqual(result["candidates"], [])

    def test_unknown_or_inactive_catalog_product_does_not_gain_purchase_link(self):
        self.catalog.connection.execute(
            "UPDATE products SET status='stale' WHERE category='tops'")
        self.catalog.connection.commit()
        result = parse_response(self.response, "draft-1", self.catalog)
        shirt = result["candidates"][0]
        self.assertEqual(shirt["suggestedCategory"], "other")
        self.assertEqual(shirt["suggestedName"], "Clothing item")
        self.assertEqual(shirt["similarProducts"], [])

    def test_provider_error_and_bad_box_fail_safely(self):
        with self.assertRaisesRegex(ValueError, "Vision error"):
            parse_response({"responses": [{"error": {"message": "quota exceeded"}}]},
                           "draft-1", self.catalog)
        groups = self.response["responses"][0]["productSearchResults"]["productGroupedResults"]
        groups[1]["boundingPoly"]["normalizedVertices"][0]["x"] = 2
        result = parse_response(self.response, "draft-1", self.catalog)
        self.assertEqual(len(result["candidates"]), 1)

    def test_live_query_is_one_bounded_product_search_request(self):
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_):
                pass

            def read(self, *_):
                return b'{"responses": [{}]}'

        with patch("product_search.urlopen", return_value=FakeResponse()) as send:
            response = query_google(b"image", "projects/demo/locations/us-east1/productSets/clothes", "token")
        self.assertEqual(response, {"responses": [{}]})
        request = send.call_args.args[0]
        body = json.loads(request.data)
        self.assertEqual(len(body["requests"]), 1)
        self.assertEqual(body["requests"][0]["features"], [{"type": "PRODUCT_SEARCH"}])
        self.assertEqual(request.get_header("Authorization"), "Bearer token")
        with self.assertRaisesRegex(ValueError, "5 MB"):
            query_google(b"a" * 5_000_001,
                         "projects/demo/locations/us-east1/productSets/clothes", "token")


if __name__ == "__main__":
    unittest.main()
