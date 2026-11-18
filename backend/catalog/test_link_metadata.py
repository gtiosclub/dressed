import json
import unittest
from pathlib import Path

from link_metadata import extract_metadata


URL = "https://shop.example/product/jeans"


def html(value):
    return '<script type="application/ld+json">' + json.dumps(value) + '</script>'


class LinkMetadataTests(unittest.TestCase):
    def test_documented_fixture_extracts_product_fields(self):
        page = Path(__file__).parent / "fixtures/product-page.html"
        result = extract_metadata(page.read_text(), URL)
        self.assertEqual(result["warnings"], [])
        self.assertEqual(result["fields"]["title"], "Fixture jeans")
        self.assertEqual(result["fields"]["price"], "52.00")
        self.assertEqual(result["fields"]["availability"], "inStock")

    def test_graph_product_has_field_evidence_and_requires_review(self):
        result = extract_metadata(html({"@graph": [{"@type": "Product", "name": "Jeans",
            "image": "/jeans.jpg", "offers": {"@type": "Offer", "price": "49.99", "priceCurrency": "USD"}}]}), URL)
        self.assertEqual(result["fields"]["price"], "49.99")
        self.assertEqual(result["fields"]["imageURL"], "https://shop.example/jeans.jpg")
        self.assertEqual(result["evidence"]["title"]["method"], "json_ld.Product.name")
        self.assertTrue(result["requiresReview"])
        self.assertNotIn("availability", result["fields"])

    def test_multiple_products_do_not_choose_first(self):
        result = extract_metadata(html([{"@type": "Product", "name": "One"},
                                        {"@type": "Product", "name": "Two"}]), URL)
        self.assertEqual(result["status"], "manual_required")
        self.assertIn("multiple_products_require_selection", result["warnings"])

    def test_multiple_offers_do_not_invent_variant_price(self):
        result = extract_metadata(html({"@type": "Product", "name": "Jeans", "offers": [
            {"price": "50"}, {"price": "60"}]}), URL)
        self.assertNotIn("price", result["fields"])
        self.assertFalse(result["variantVerified"])

    def test_invalid_json_falls_back_to_open_graph_without_price_guess(self):
        result = extract_metadata('<script type="application/ld+json">invalid</script>'
                                  '<meta property="og:title" content="Jeans &amp; jacket">', URL)
        self.assertEqual(result["fields"], {"title": "Jeans & jacket"})
        self.assertIn("invalid_json_ld", result["warnings"])

    def test_blocked_page_remains_manual(self):
        self.assertEqual(extract_metadata("<title>Access denied</title>", URL)["status"], "manual_required")

    def test_invalid_image_and_nonfinite_price_are_omitted(self):
        result = extract_metadata(html({"@type": "Product", "name": "Jeans", "image": "http://localhost/x",
                                        "offers": {"price": "NaN"}}), URL)
        self.assertNotIn("imageURL", result["fields"])
        self.assertNotIn("price", result["fields"])


if __name__ == "__main__":
    unittest.main()
