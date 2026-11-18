import io
import json
import unittest
from urllib.error import HTTPError

from shopping_experiment import ProviderError, SerpApiClient, evaluate, normalize_search, public_url


def response():
    return {"shopping_results": [{"product_id": "fixture-1", "title": "Fixture jeans",
            "source": "Store A", "price": "$50", "product_link": "https://www.google.com/shopping/product/1",
            "immersive_product_page_token": "fixture-token"}]}


class ShoppingTests(unittest.TestCase):
    def test_google_comparison_query_spaces_are_encoded(self):
        raw = response()
        raw["shopping_results"][0]["product_link"] = "https://www.google.com/search?q=baggy jeans&udm=28"
        candidate = normalize_search(raw)[0]
        self.assertEqual(candidate["comparisonURL"], "https://www.google.com/search?q=baggy%20jeans&udm=28")
        self.assertEqual(candidate["offers"], [])

    def test_relative_google_redirect_preserves_offer_without_claiming_merchant_url(self):
        stores = [{"name": "Fixture retailer", "link": "/goto?url=fixture-opaque-token", "price": "$59.95"}]
        report = evaluate(["jeans"], lambda _: response(),
                          lambda _: {"product_results": {"stores": stores}}, 1)
        candidate = report["runs"][0]["candidates"][0]
        self.assertEqual(candidate["resolution"], "merchant_redirect_pending")
        self.assertEqual(candidate["offers"], [])
        self.assertEqual(candidate["pendingOffers"][0]["priceText"], "$59.95")
        self.assertEqual(candidate["pendingOffers"][0]["redirectURL"], "https://www.google.com/goto?url=fixture-opaque-token")
        self.assertIsNone(candidate["pendingOffers"][0]["productURL"])
        self.assertEqual(report["summary"]["pendingRedirectOffers"], 1)
        self.assertEqual(report["summary"]["detailFailures"], 0)
        self.assertEqual(report["summary"]["candidatesWithMerchantURL"], 0)

    def test_comparison_link_never_becomes_merchant_offer(self):
        candidate = normalize_search(response())[0]
        self.assertEqual(candidate["offers"], [])
        self.assertEqual(candidate["resolution"], "unresolved")

    def test_details_keep_merchant_prices_separate_and_deduplicate(self):
        stores = [{"name": "Store B", "link": "https://shop.example/jeans", "price": "$60"},
                  {"name": "Store B", "link": "https://shop.example/jeans", "price": "$60"},
                  {"name": "Store C", "link": "https://other.example/jeans"}]
        result = normalize_search(response(), lambda _: {"product_results": {"stores": stores}}, 1)[0]
        self.assertEqual(len(result["offers"]), 2)
        self.assertEqual(result["offers"][0]["priceText"], "$60")
        self.assertIsNone(result["offers"][1]["priceText"])
        self.assertFalse(result["offers"][0]["destinationVerified"])

    def test_budget_counts_failed_attempts_and_redacts_errors(self):
        class Opener:
            def open(self, request, timeout):
                raise HTTPError(request.full_url, 401, "secret-key", {}, None)
        client = SerpApiClient("secret-key", 1, Opener())
        with self.assertRaisesRegex(ProviderError, "^provider_http_401$"):
            client.search("jeans")
        with self.assertRaisesRegex(ProviderError, "request_budget_exhausted"):
            client.search("jeans")
        self.assertEqual(client.requests, 1)

    def test_request_uses_fixed_endpoint_and_parameters(self):
        class Opener:
            def open(self, request, timeout):
                self.url = request.full_url
                return io.BytesIO(json.dumps(response()).encode())
        opener = Opener()
        client = SerpApiClient("test-key", 2, opener)
        self.assertEqual(client.search("blue jeans"), response())
        self.assertTrue(opener.url.startswith("https://serpapi.com/search.json?"))
        self.assertIn("gl=us", opener.url)
        self.assertIn("q=blue+jeans", opener.url)

    def test_duplicate_results_and_detail_budget(self):
        raw = response()
        raw["shopping_results"] *= 2
        calls = []
        result = normalize_search(raw, lambda token: calls.append(token) or {"product_results": {"stores": []}}, 1)
        self.assertEqual(len(result), 1)
        self.assertEqual(len(calls), 1)

    def test_empty_and_failed_queries_are_distinct(self):
        def search(query):
            if query == "failure":
                raise ProviderError("provider_http_429")
            return {"shopping_results": []}
        result = evaluate(["empty", "failure"], search)
        self.assertEqual(result["summary"]["failedQueries"], 1)
        self.assertEqual(result["summary"]["candidates"], 0)
        self.assertIsNone(result["runs"][0]["error"])

    def test_bad_urls_are_excluded(self):
        for url in ["http://shop.example/x", "https://127.0.0.1/x", "https://localhost/x",
                    "https://user:pass@shop.example/x", "https://shop.example:44/x",
                    "https://shop.local/x", "https://shop.example/has space"]:
            self.assertIsNone(public_url(url), url)

    def test_missing_results_is_not_silent_empty_success(self):
        with self.assertRaisesRegex(ProviderError, "missing_shopping_results"):
            normalize_search({})

    def test_malformed_nested_response_becomes_reported_error(self):
        with self.assertRaisesRegex(ProviderError, "missing_shopping_results"):
            normalize_search({"search_information": None})
        candidate = normalize_search(response(), lambda _: None, 1)[0]
        self.assertEqual(candidate["resolution"], "missing_stores")

    def test_detail_failure_preserves_candidate_for_manual_review(self):
        def resolve(_):
            raise ProviderError("provider_http_429")
        report = evaluate(["jeans"], lambda _: response(), resolve, 1)
        self.assertEqual(report["runs"][0]["candidates"][0]["resolution"], "provider_http_429")
        self.assertEqual(report["summary"]["failedQueries"], 0)
        self.assertEqual(report["summary"]["detailFailures"], 1)

    def test_oversized_and_invalid_provider_responses(self):
        class Opener:
            body = b"not json"
            def open(self, request, timeout):
                return io.BytesIO(self.body)
        opener = Opener()
        client = SerpApiClient("test", 3, opener)
        with self.assertRaisesRegex(ProviderError, "invalid_provider_json"):
            client.search("jeans")
        opener.body = b"x" * 2_000_001
        with self.assertRaisesRegex(ProviderError, "response_too_large"):
            client.search("jeans")
        opener.body = b'{"error":"message containing secret"}'
        with self.assertRaisesRegex(ProviderError, "^provider_response_error$"):
            client.search("jeans")


if __name__ == "__main__":
    unittest.main()
