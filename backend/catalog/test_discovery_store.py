import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from discovery_store import DiscoveryRun, sanitize
from shopping_experiment import ProviderError, evaluate


class DiscoveryStoreTests(unittest.TestCase):
    def test_sanitized_response_is_saved_before_normalization(self):
        with tempfile.TemporaryDirectory() as directory:
            run = DiscoveryRun(root=directory, secret="secret-key")
            raw = {"api_key": "secret-key", "url": "https://serpapi.com/search?api_key=secret-key&q=jeans",
                   "shopping_results": [], "message": "secret-key"}
            self.assertEqual(run.capture("searches", "jeans", lambda _: raw), raw)
            stored = (run.directory / "responses.json").read_text()
            self.assertNotIn("secret-key", stored)
            self.assertEqual(json.loads(stored)["searches"]["jeans"]["api_key"], "[REDACTED]")

    def test_repeated_discovery_upserts_candidate_and_retains_observations(self):
        with tempfile.TemporaryDirectory() as directory:
            query = {"query": "jeans", "candidates": [{"id": "stable-1", "title": "Jeans", "offers": []}]}
            first = DiscoveryRun(root=directory)
            first.record_query(query)
            first.finish()
            second = DiscoveryRun(root=directory)
            query["candidates"][0]["title"] = "Updated jeans"
            second.record_query(query)
            second.finish()
            self.assertNotEqual(first.directory, second.directory)
            with sqlite3.connect(second.database) as connection:
                self.assertEqual(connection.execute("SELECT count(*) FROM candidates").fetchone()[0], 1)
                self.assertEqual(connection.execute("SELECT count(*) FROM observations").fetchone()[0], 2)
                state, data = connection.execute("SELECT state, data_json FROM candidates").fetchone()
                self.assertEqual(state, "needs_merchant_url")
                self.assertEqual(json.loads(data)["title"], "Updated jeans")

    def test_failure_preserves_completed_queries_and_response_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            run = DiscoveryRun(root=directory, mode="fixture")
            def search(query):
                if query == "failure":
                    raise ProviderError("provider_http_429")
                return {"shopping_results": []}
            report = evaluate(["empty", "failure"], lambda q: run.capture("searches", q, search),
                              on_query=run.record_query)
            path = run.finish(report, "completed_with_errors")
            self.assertEqual(json.loads(path.read_text())["summary"]["failedQueries"], 1)
            raw = json.loads((run.directory / "responses.json").read_text())
            self.assertIn("empty", raw["searches"])
            self.assertEqual(raw["errors"][0]["errorType"], "ProviderError")
            self.assertFalse((Path(directory) / "discovery.sqlite").exists())

    def test_nested_keys_and_url_credentials_are_redacted(self):
        result = sanitize({"nested": [{"Authorization": "Bearer secret"}],
                           "url": "https://api.example/?api_key=unknown&x=1"})
        self.assertNotIn("unknown", json.dumps(result))
        self.assertEqual(result["nested"][0]["Authorization"], "[REDACTED]")

    def test_shared_link_preserves_provenance_and_original_observation_time(self):
        with tempfile.TemporaryDirectory() as directory:
            run = DiscoveryRun(root=directory)
            candidate = {"id": "link-1", "offers": [], "reviewState": "needs_metadata",
                         "sourceURL": "https://shop.example/jeans", "metadata": {"requiresReview": True}}
            run.record_query({"query": candidate["sourceURL"], "candidates": [candidate]},
                             observed_at="2026-11-17T12:00:00+00:00", provider="shared-link-html")
            with sqlite3.connect(run.database) as connection:
                self.assertEqual(connection.execute("SELECT provider, state, first_seen_at FROM candidates").fetchone(),
                                 ("shared-link-html", "needs_metadata", "2026-11-17T12:00:00+00:00"))


if __name__ == "__main__":
    unittest.main()
