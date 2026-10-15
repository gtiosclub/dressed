import copy
import json
import tempfile
import threading
import unittest
from http.server import HTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen

from catalog import CatalogDatabase, make_handler


FIXTURE = Path(__file__).parent / "fixtures" / "demo-feed.json"


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.db = CatalogDatabase(Path(self.temp.name) / "catalog.sqlite")
        self.feed = json.loads(FIXTURE.read_text())

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def test_repeated_import_keeps_stable_products_and_updates_price(self):
        first = self.db.ingest(self.feed, now="2026-10-12T00:00:00+00:00")
        first_ids = [item["id"] for item in self.db.search()["products"]]
        second = self.db.ingest(self.feed, now="2026-10-13T00:00:00+00:00")
        self.assertEqual(first["created"], 3)
        self.assertEqual(second["unchanged"], 3)
        self.assertEqual(first_ids, [item["id"] for item in self.db.search()["products"]])

        changed = copy.deepcopy(self.feed)
        changed["products"][0]["priceCents"] = 4200
        third = self.db.ingest(changed, now="2026-10-14T00:00:00+00:00")
        self.assertEqual(third["changed"], 1)
        self.assertEqual(self.db.search("Blue")["products"][0]["priceCents"], 4200)

    def test_only_complete_successful_scans_age_out_missing_products(self):
        self.db.ingest(self.feed)
        shortened = copy.deepcopy(self.feed)
        shortened["products"] = shortened["products"][:2]
        shortened["complete"] = False
        self.db.ingest(shortened)
        self.assertEqual(self.db.search()["total"], 3)

        shortened["complete"] = True
        self.db.ingest(shortened)
        self.assertEqual(self.db.search()["total"], 2)
        missing_id = self.db.connection.execute(
            "SELECT id FROM products WHERE external_id='shoes-003'"
        ).fetchone()[0]
        self.assertEqual(self.db.get(missing_id)["status"], "stale")

        self.db.ingest(shortened)
        self.assertEqual(self.db.get(missing_id)["status"], "unavailable")
        self.db.ingest(self.feed)
        self.assertEqual(self.db.get(missing_id)["status"], "active")

    def test_bad_url_rejects_entire_feed_and_records_failed_run(self):
        self.db.ingest(self.feed)
        invalid = copy.deepcopy(self.feed)
        invalid["products"][0]["productURL"] = "https://unapproved.example/products/top-001"
        invalid["products"][1]["priceCents"] = 1
        with self.assertRaisesRegex(ValueError, "approved host"):
            self.db.ingest(invalid)
        self.assertEqual(self.db.search("pants")["products"][0]["priceCents"], 6400)
        self.assertEqual(self.db.connection.execute(
            "SELECT status FROM runs ORDER BY rowid DESC LIMIT 1"
        ).fetchone()[0], "failed")

    def test_http_api_is_read_only_and_filters_results(self):
        self.db.ingest(self.feed)
        server = HTTPServer(("127.0.0.1", 0), make_handler(self.db))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            with urlopen(base + "/products?q=shirt&category=tops") as response:
                result = json.load(response)
            self.assertEqual(result["total"], 1)
            self.assertEqual(result["products"][0]["title"], "Blue cotton shirt")
            with self.assertRaises(HTTPError) as context:
                urlopen(base + "/products?category=invalid")
            self.assertEqual(context.exception.code, 400)
            context.exception.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
