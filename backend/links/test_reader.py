import json
import socket
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

import reader
from reader import UnsafeURL, normalize_url, read_product_link

FIX = Path(__file__).parent / "fixtures"


def page(name: str) -> str:
    return (FIX / name).read_text()


def fake(name: str, status: int = 200):
    return lambda url, resolver=None: (status, url, page(name) if name else "")


class NormalizeTests(unittest.TestCase):
    def test_drops_tracking_and_fragment_keeps_variant(self):
        url = normalize_url("https://Shop.example.com/p/jacket?utm_source=x&fbclid=1&variant=42#reviews")
        self.assertEqual(url, "https://shop.example.com/p/jacket?variant=42")

    def test_refuses_unsafe_links(self):
        for bad in ["http://a.com/x", "https://user:pw@a.com/x", "https://a.com:8443/x",
                    "https://localhost/x", "https://printer.local/x", "ftp://a.com", ""]:
            with self.assertRaises(UnsafeURL, msg=bad):
                normalize_url(bad)

    def test_refuses_private_addresses(self):
        private = lambda host, port, type=0: [(0, 0, 0, "", ("10.0.0.5", 443))]
        public = lambda host, port, type=0: [(0, 0, 0, "", ("93.184.216.34", 443))]
        with self.assertRaises(UnsafeURL):
            reader.assert_public_host("internal.example.com", private)
        for literal in ("127.0.0.1", "169.254.169.254", "192.168.1.1"):
            with self.assertRaises(UnsafeURL):
                reader.assert_public_host(literal, public)
        reader.assert_public_host("shop.example.com", public)


class ExtractTests(unittest.TestCase):
    def draft(self, name, url="https://shop.example.com/p/x"):
        return read_product_link(url, "imp-1", fetcher=fake(name))

    def test_jsonld_fills_only_what_page_states(self):
        d = self.draft("jacket-jsonld.html")
        f = d["fields"]
        self.assertEqual(d["status"], "ready")
        self.assertEqual(f["name"]["value"], "Rain Jacket")
        self.assertEqual(f["name"]["source"], "json-ld")
        self.assertEqual(f["image"]["value"], "https://cdn.example.com/rain-jacket.jpg")
        self.assertEqual(f["retailer"]["value"], "Example Outerwear Co")
        self.assertEqual(f["category"]["value"], "outerwear")
        self.assertEqual(f["price"]["value"], {"amount": "89.00", "currency": "USD"})
        self.assertEqual(f["availability"]["value"], "In stock")
        self.assertEqual(f["link"]["state"], "from_link")
        self.assertEqual(d["canonicalLink"], "https://shop.example.com/products/rain-jacket")

    def test_variant_stays_open_without_link_parameter(self):
        d = self.draft("jacket-jsonld.html")
        self.assertIsNone(d["fields"]["variant"]["value"])
        self.assertEqual(d["fields"]["variant"]["state"], "open")

    def test_variant_filled_from_link_parameter(self):
        d = self.draft("jacket-jsonld.html", "https://shop.example.com/p/x?variant=navy-m")
        self.assertEqual(d["fields"]["variant"]["value"], "navy-m")
        self.assertEqual(d["fields"]["variant"]["state"], "from_link")

    def test_multiple_offers_leave_price_and_stock_open(self):
        f = self.draft("multi-offer.html")["fields"]
        self.assertEqual(f["name"]["value"], "Wool Coat")
        self.assertIsNone(f["price"]["value"])
        self.assertIsNone(f["availability"]["value"])

    def test_price_without_currency_stays_open(self):
        f = self.draft("script-price.html")["fields"]
        self.assertEqual(f["name"]["value"], "Denim Jeans")
        self.assertIsNone(f["price"]["value"])

    def test_open_graph_fallback_and_domain_retailer(self):
        f = self.draft("og-only.html")["fields"]
        self.assertEqual((f["name"]["value"], f["name"]["source"]), ("Canvas Sneakers", "open-graph"))
        self.assertEqual(f["image"]["value"], "https://shop.example.com/img/sneakers.jpg")
        self.assertEqual(f["retailer"]["value"], "shop.example.com")
        self.assertEqual(f["retailer"]["state"], "from_link")

    def test_microdata(self):
        f = self.draft("microdata.html")["fields"]
        self.assertEqual(f["name"]["value"], "Linen Shirt")
        self.assertEqual(f["price"]["value"], {"amount": "45.00", "currency": "EUR"})
        self.assertEqual(f["availability"]["value"], "Preorder")

    def test_unknown_category_is_only_a_suggestion(self):
        html = '<script type="application/ld+json">{"@type":"Product","name":"Hat","category":"Headwear"}</script>'
        d = read_product_link("https://a.example.com/h", "i", fetcher=lambda u, r=None: (200, u, html))
        self.assertIsNone(d["fields"]["category"]["value"])
        self.assertEqual(d["fields"]["category"]["state"], "suggested")

    def test_thin_page_returns_message_and_keeps_link(self):
        d = self.draft("thin.html")
        self.assertEqual(d["status"], "ready")
        self.assertIsNotNone(d["message"])
        self.assertIsNone(d["fields"]["name"]["value"])
        self.assertEqual(d["fields"]["link"]["value"], "https://shop.example.com/p/x")


class BlockedAndFailureTests(unittest.TestCase):
    def test_status_codes_are_blocked_not_retried(self):
        for status in (401, 403, 429):
            d = read_product_link("https://shop.example.com/p", "i", fetcher=fake(None, status))
            self.assertEqual(d["status"], "blocked", status)
            self.assertEqual(d["fields"]["link"]["value"], "https://shop.example.com/p")

    def test_bot_wall_page_is_blocked(self):
        d = read_product_link("https://shop.example.com/p", "i", fetcher=fake("blocked.html"))
        self.assertEqual(d["status"], "blocked")

    def test_timeout_is_failed_with_link_kept(self):
        def boom(url, resolver=None):
            raise TimeoutError("slow")
        d = read_product_link("https://shop.example.com/p", "i", fetcher=boom)
        self.assertEqual(d["status"], "failed")
        self.assertEqual(d["fields"]["link"]["state"], "from_link")

    def test_unsafe_link_never_fetches(self):
        called = []
        d = read_product_link("http://shop.example.com/p", "i", fetcher=lambda u, r=None: called.append(u))
        self.assertEqual(d["status"], "failed")
        self.assertEqual(called, [])


class ServiceTests(unittest.TestCase):
    def setUp(self):
        import local_service
        local_service.Handler.fixture_html = page("jacket-jsonld.html")
        local_service.Handler.drafts = {}
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), local_service.Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def post(self, body):
        req = Request(self.base + "/product-imports", json.dumps(body).encode(),
                      {"Content-Type": "application/json"})
        with urlopen(req) as response:
            return json.loads(response.read())

    def test_retry_with_same_request_id_returns_same_draft(self):
        body = {"url": "https://shop.example.com/p/jacket", "clientRequestId": "req-1"}
        first, second = self.post(body), self.post(body)
        self.assertEqual(first["importId"], second["importId"])
        self.assertEqual(first, second)

    def test_rejects_bad_request(self):
        from urllib.error import HTTPError
        with self.assertRaises(HTTPError) as ctx:
            self.post({"url": "https://shop.example.com/p"})
        self.assertEqual(ctx.exception.code, 400)


if __name__ == "__main__":
    unittest.main()
