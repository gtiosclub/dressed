import copy
import unittest
from urllib.error import HTTPError

from merchant_redirects import GoogleRedirectClient, resolve_candidates


class RedirectTests(unittest.TestCase):
    def test_google_redirect_resolves_without_fetching_destination_and_caches(self):
        class Opener:
            urls = []
            def open(self, request, timeout):
                self.urls.append(request.full_url)
                raise HTTPError(request.full_url, 302, "Found", {"Location": "https://shop.example/jeans"}, None)
        opener = Opener()
        client = GoogleRedirectClient(1, opener)
        result = client.resolve("/goto?url=fixture")
        self.assertEqual(result["productURL"], "https://shop.example/jeans")
        self.assertEqual(client.resolve("/goto?url=fixture"), result)
        self.assertEqual(opener.urls, ["https://www.google.com/goto?url=fixture"])
        self.assertEqual(client.resolve("/goto?url=second")["status"], "redirect_budget_exhausted")

    def test_arbitrary_fetches_and_private_destinations_are_rejected(self):
        client = GoogleRedirectClient()
        self.assertEqual(client.resolve("https://attacker.example/goto?url=x")["status"], "unsupported_redirect")
        self.assertEqual(client.requests, 0)
        class Opener:
            def open(self, request, timeout):
                raise HTTPError(request.full_url, 302, "Found", {"Location": "http://127.0.0.1/private"}, None)
        self.assertEqual(GoogleRedirectClient(1, Opener()).resolve("/goto?url=x")["status"], "unsupported_destination")

    def test_resolved_offer_retains_price_and_is_not_product_verified(self):
        query = {"candidates": [{"offers": [], "pendingOffers": [
            {"id": "old", "redirectURL": "https://www.google.com/goto?url=x", "productURL": None,
             "priceText": "$50", "merchant": "Store", "variantVerified": False}]}]}
        resolve_candidates(query, lambda _: {"status": "resolved", "productURL": "https://shop.example/jeans"})
        candidate = query["candidates"][0]
        self.assertEqual(candidate["pendingOffers"], [])
        self.assertEqual(candidate["offers"][0]["priceText"], "$50")
        self.assertFalse(candidate["offers"][0]["destinationVerified"])
        self.assertFalse(candidate["offers"][0]["variantVerified"])
        self.assertEqual(candidate["resolution"], "merchant_url_found")


if __name__ == "__main__":
    unittest.main()
