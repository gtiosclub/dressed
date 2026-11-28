import json
import unittest

from link_metadata import extract_metadata
from retail_product import from_metadata, from_candidate
from shopping_experiment import normalize_search


URL = "https://shop.example/jeans"


def markup(value):
    return '<script type="application/ld+json">' + json.dumps(value) + '</script>'


class RetailProductTests(unittest.TestCase):
    def test_detail_gallery_and_options_are_retained_without_selecting_variant(self):
        response = {"shopping_results": [{"product_id": "1", "title": "Jeans", "immersive_product_page_token": "token"}]}
        detail = {"product_results": {"brand": "Example", "thumbnails": ["https://img.example/front.jpg", "https://img.example/back.jpg"],
                  "variants": [{"title": "Size", "items": [{"name": "S"}, {"name": "M"}]}], "stores": []}}
        candidate = normalize_search(response, lambda _: detail, 1)[0]
        product = from_candidate(candidate, "2026-11-17T00:00:00Z")
        self.assertEqual(len(product["photos"]), 2)
        self.assertEqual(product["variantOptions"], {"Size": ["S", "M"]})
        self.assertEqual(product["variants"], [])
        self.assertEqual(product["brand"], "Example")

    def test_gallery_attributes_identifiers_description_and_offer_survive(self):
        value = {"@type": "Product", "name": "Jeans", "description": "Cotton denim",
                 "brand": {"name": "Example"}, "sku": "J-1", "color": "Blue", "material": "Cotton",
                 "image": ["/front.jpg", {"url": "/back.jpg"}, "/front.jpg", "javascript:bad"],
                 "offers": {"@type": "Offer", "price": "49.95", "priceCurrency": "USD", "url": URL}}
        product = from_metadata(extract_metadata(markup(value), URL))
        self.assertEqual(len(product["photos"]), 2)
        self.assertEqual(product["identifiers"], {"sku": "J-1"})
        self.assertEqual(product["attributes"]["color"], "Blue")
        self.assertEqual(product["description"], "Cotton denim")
        self.assertEqual(product["offers"][0]["amount"], "49.95")
        self.assertTrue(product["requiresReview"])
        self.assertEqual(product["photos"][0]["reuseStatus"], "unreviewed")

    def test_variants_and_price_range_never_become_selected_exact_price(self):
        value = {"@type": "ProductGroup", "name": "Jeans", "hasVariant": [
            {"@type": "Product", "sku": "J-BLUE", "color": "Blue", "size": "M", "url": URL + "?size=M"},
            {"@type": "Product", "sku": "J-BLACK", "color": "Black", "size": "L"}],
            "offers": {"@type": "AggregateOffer", "lowPrice": "30", "highPrice": "60", "priceCurrency": "USD"}}
        product = from_metadata(extract_metadata(markup(value), URL))
        self.assertEqual(len(product["variants"]), 2)
        self.assertTrue(all(not v["selected"] for v in product["variants"]))
        self.assertIsNone(product["offers"][0]["amount"])
        self.assertEqual(product["offers"][0]["lowPrice"], "30")

    def test_exact_url_selects_product_over_recommendation(self):
        value = [{"@type": "Product", "name": "Recommendation", "url": "https://shop.example/other"},
                 {"@type": "Product", "name": "Actual", "url": URL}]
        self.assertEqual(extract_metadata(markup(value), URL)["fields"]["title"], "Actual")

    def test_multiple_open_graph_photos_and_description(self):
        value = '<meta property="og:image" content="/front.jpg"><meta property="og:image" content="/back.jpg">'
        value += '<meta property="og:description" content="Product description">'
        product = from_metadata(extract_metadata(value, URL))
        self.assertEqual(len(product["photos"]), 2)
        self.assertEqual(product["description"], "Product description")

    def test_search_keeps_store_offers_separate_and_unknown_fields_empty(self):
        candidate = {"id": "one", "title": "Jeans", "imageURL": "https://images.example/jeans.jpg",
                     "comparisonURL": "https://www.google.com/search?q=jeans", "offers": [
                         {"merchant": "A", "productURL": URL, "priceText": "$50"},
                         {"merchant": "B", "productURL": "https://other.example/jeans", "priceText": "$60"}]}
        product = from_candidate(candidate, "2026-11-17T00:00:00Z")
        self.assertIsNone(product["productURL"])
        self.assertIsNone(product["brand"])
        self.assertEqual(len(product["offers"]), 2)
        self.assertIsNone(product["offers"][0]["currency"])


if __name__ == "__main__":
    unittest.main()
