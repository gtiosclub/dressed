import copy
import json
import threading
import tempfile
import unittest
import uuid
from http.server import HTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch

from service import SearchError, SearchSession, make_handler, normalize, search_lens
from compare import compare, CatalogDatabase

FIXTURE = json.loads((Path(__file__).parent / "fixtures/lens.json").read_text())
JPEG = b"\xff\xd8\xfftest-crop"  # Transport fixture; live requests use UIKit-encoded JPEGs.


class SearchTests(unittest.TestCase):
    def test_filters_unsafe_and_unapproved_urls_deduplicates_and_preserves_unknown_price(self):
        response = copy.deepcopy(FIXTURE)
        response["visual_matches"] += [
            response["visual_matches"][0],
            {"title": "Unsafe", "link": "http://shop.example/item"},
            {"title": "Spoof", "link": "https://shop.example.evil.test/item"},
            {"title": "Private", "link": "https://127.0.0.1/item"},
            {"title": "Credentials", "link": "https://key@shop.example/item"},
            {"title": "Wrong port", "link": "https://shop.example:8080/item"},
        ]
        hits = normalize(response, {"shop.example"})
        self.assertEqual(len(hits), 2)
        self.assertEqual(hits[0]["price"], "$49.00")
        self.assertIsNone(hits[1]["price"])
        self.assertIsNone(hits[0]["imageURL"])
        self.assertEqual(hits[0]["source"], "shop.example")
        self.assertNotIn("exact", hits[0])

    def test_provider_errors_are_not_empty_successes(self):
        for response in ({"error": "secret upstream error"}, {}, {"search_metadata": None},
                         {"search_metadata": {"status": "Processing"}},
                         {"search_metadata": {"status": "Success"}, "visual_matches": "bad"}):
            with self.subTest(response=response), self.assertRaises(SearchError):
                normalize(response, {"shop.example"})
        self.assertEqual(normalize({"search_metadata": {"status": "Success"}}, set()), [])

    def test_retry_reuses_result_but_changed_image_cannot_reuse_id(self):
        calls = []
        session = SearchSession(lambda image: calls.append(image) or FIXTURE, {"shop.example"}, limit=1)
        request_id = str(uuid.uuid4())
        first = session.search(request_id, JPEG)
        self.assertEqual(first, session.search(request_id, JPEG))
        self.assertEqual(len(calls), 1)
        with self.assertRaises(SearchError) as conflict:
            session.search(request_id, JPEG + b"changed")
        self.assertEqual(conflict.exception.status, 409)
        with self.assertRaises(SearchError) as limited:
            session.search(str(uuid.uuid4()), JPEG)
        self.assertEqual(limited.exception.status, 429)

    def test_failed_requests_still_consume_attempt_budget(self):
        session = SearchSession(lambda image: {"error": "failure"}, set(), limit=1)
        with self.assertRaises(SearchError):
            session.search(str(uuid.uuid4()), JPEG)
        with self.assertRaises(SearchError) as limited:
            session.search(str(uuid.uuid4()), JPEG)
        self.assertEqual(limited.exception.status, 429)

    def test_expired_cache_does_not_bypass_budget(self):
        session = SearchSession(lambda image: FIXTURE, {"shop.example"}, limit=1)
        request_id = str(uuid.uuid4())
        with patch("service.time.monotonic", return_value=0):
            session.search(request_id, JPEG)
        with patch("service.time.monotonic", return_value=601), self.assertRaises(SearchError) as limited:
            session.search(request_id, JPEG)
        self.assertEqual(limited.exception.status, 429)

    def test_lens_upload_precedes_visual_match_query(self):
        with patch("service.provider_json", side_effect=[{"image_id": "temporary-image"}, FIXTURE]) as send:
            self.assertEqual(search_lens(JPEG, "test-secret"), FIXTURE)
        upload, search = [call.args[0] for call in send.call_args_list]
        self.assertEqual(upload.full_url, "https://serpapi.com/image")
        self.assertIn(JPEG, upload.data)
        self.assertIn(b'name="api_key"', upload.data)
        self.assertIn("image_id=temporary-image", search.full_url)
        self.assertIn("type=visual_matches", search.full_url)
        self.assertNotIn("type=products", search.full_url)

    def test_local_http_accepts_native_request_and_rejects_browser_host_and_bad_input(self):
        session = SearchSession(lambda image: FIXTURE, {"shop.example"}, fixture=True)
        server = HTTPServer(("127.0.0.1", 0), make_handler(session))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/product-search"

        def request(headers=None, data=JPEG):
            fields = {"Content-Type": "image/jpeg", "X-Request-ID": str(uuid.uuid4())}
            fields.update(headers or {})
            return Request(url, data=data, headers=fields)

        try:
            with urlopen(request()) as response:
                result = json.load(response)
                self.assertIn("Fixture", result["provider"])
                self.assertEqual(len(result["matches"]), 2)
            for headers, data, expected in [
                ({"Origin": "https://evil.test"}, JPEG, 403),
                ({"Host": "evil.test"}, JPEG, 403),
                ({"Content-Type": "application/json"}, JPEG, 415),
                ({"X-Request-ID": "bad"}, JPEG, 400),
                ({}, b"not an image", 400),
                ({"Content-Length": "500001"}, JPEG, 413),
            ]:
                with self.subTest(headers=headers, expected=expected), self.assertRaises(HTTPError) as rejected:
                    urlopen(request(headers, data))
                self.assertEqual(rejected.exception.code, expected)
                rejected.exception.close()
            self.assertEqual(session.calls, 1)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_comparison_keeps_lens_errors_and_real_catalog_baseline_results(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "crop.jpg").write_bytes(JPEG)
            catalog = CatalogDatabase(root / "catalog.sqlite")
            feed_path = Path(__file__).resolve().parents[1] / "catalog/fixtures/demo-feed.json"
            catalog.ingest(json.loads(feed_path.read_text()))
            try:
                with patch("compare.urlopen", side_effect=TimeoutError):
                    rows = compare([{"id": "shirt-1", "imagePath": "crop.jpg",
                                     "query": "shirt", "category": "tops"}], root, catalog, 8767)
                self.assertEqual(rows[0]["sampleId"], "shirt-1")
                self.assertIn("error", rows[0]["lens"])
                self.assertEqual(rows[0]["catalogTextBaseline"]["products"][0]["title"], "Blue cotton shirt")
                self.assertEqual(rows[0]["judgments"], [])
            finally:
                catalog.close()


if __name__ == "__main__":
    unittest.main()
