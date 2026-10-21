"""Offline contract checks for the eBay Browse response adapter."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from catalog import CatalogDatabase
from ebay_browse import convert_response


FIXTURE = Path(__file__).parent / "fixtures/ebay-browse-response.json"


class EbayBrowseAdapterTests(unittest.TestCase):
    def setUp(self):
        self.response = json.loads(FIXTURE.read_text())

    def test_saved_response_enters_search_with_stable_provenance(self):
        feed, skipped = convert_response(self.response, category="shoes")
        self.assertFalse(feed["complete"])
        self.assertEqual(skipped, 0)
        self.assertEqual(feed["products"][0]["priceCents"], 4999)
        self.assertEqual(feed["products"][0]["sourceCategory"], "Athletic Shoes")

        with tempfile.TemporaryDirectory() as directory:
            db = CatalogDatabase(Path(directory) / "catalog.sqlite")
            try:
                first = db.ingest(feed, now="2026-10-16T00:00:00+00:00")
                product = db.search("sneakers", "shoes")["products"][0]
                second = db.ingest(feed, now="2026-10-16T01:00:00+00:00")
                self.assertEqual((first["created"], second["unchanged"]), (2, 2))
                self.assertEqual(product["sourceId"], "ebay-us-browse")
                self.assertEqual(product["externalId"], "v1|fixture-shoe-1|0")
                self.assertEqual(product["productURL"], "https://www.ebay.com/itm/fixture-shoe-1")
            finally:
                db.close()

    def test_untrusted_urls_and_invalid_prices_are_not_imported(self):
        response = copy.deepcopy(self.response)
        response["itemSummaries"][0]["itemWebUrl"] = "https://attacker.example/item"
        response["itemSummaries"][1]["image"] = {"imageUrl": "https://attacker.example/image"}
        response["itemSummaries"][1]["price"] = {"value": "NaN", "currency": "USD"}
        feed, skipped = convert_response(response, category="shoes")
        self.assertEqual(skipped, 1)
        self.assertEqual(len(feed["products"]), 1)
        self.assertNotIn("imageURL", feed["products"][0])
        self.assertNotIn("priceCents", feed["products"][0])

    def test_a_partial_search_does_not_mark_other_listings_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            db = CatalogDatabase(Path(directory) / "catalog.sqlite")
            try:
                full, _ = convert_response(self.response, category="shoes")
                db.ingest(full)
                one = copy.deepcopy(self.response)
                one["itemSummaries"] = one["itemSummaries"][:1]
                partial, _ = convert_response(one, category="shoes")
                db.ingest(partial)
                db.ingest(partial)
                self.assertEqual(db.search(category="shoes")["total"], 2)
            finally:
                db.close()

    def test_empty_search_is_a_valid_partial_feed(self):
        feed, skipped = convert_response({"total": 0}, category="shoes")
        self.assertEqual(feed["products"], [])
        self.assertFalse(feed["complete"])
        self.assertEqual(skipped, 0)


if __name__ == "__main__":
    unittest.main()
