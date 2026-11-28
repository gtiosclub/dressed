import unittest

from livostyle import category_for, convert_dataset


class LivostyleTests(unittest.TestCase):
    def setUp(self):
        self.record = {
            "id": "123", "title": "Wide Leg Jeans",
            "url": "https://livostyle.com/products/wide-leg-jeans",
            "category": {"name": "Jeans"},
            "price": {"min_usd": 42.99, "max_usd": 42.99, "currency": "USD"},
            "featured_image_url": "https://cdn.shopify.com/s/files/test.webp",
            "variants": [{"in_stock": True}],
        }

    def test_converts_real_feed_shape(self):
        product = convert_dataset([self.record])["products"][0]
        self.assertEqual(product["category"], "pants")
        self.assertEqual(product["priceCents"], 4299)
        self.assertEqual(product["availability"], "inStock")
        self.assertNotIn("imageURL", product)

    def test_variable_price_is_not_presented_as_exact(self):
        self.record["price"]["max_usd"] = 48.99
        product = convert_dataset([self.record])["products"][0]
        self.assertNotIn("priceCents", product)

    def test_rejects_untrusted_product_and_image_urls(self):
        self.record["url"] = "https://evil.example/products/jeans"
        with self.assertRaisesRegex(ValueError, "approved host"):
            convert_dataset([self.record])
        self.record["url"] = "https://livostyle.com/products/wide-leg-jeans"
        self.record["featured_image_url"] = "https://evil.example/image.jpg"
        with self.assertRaisesRegex(ValueError, "approved host"):
            convert_dataset([self.record], include_images=True)

    def test_requires_stable_id(self):
        del self.record["id"]
        with self.assertRaisesRegex(ValueError, "stable id"):
            convert_dataset([self.record])

    def test_category_mapping(self):
        self.assertEqual(category_for("Coats & Jackets"), "outerwear")
        self.assertEqual(category_for("Earrings"), "accessories")
        self.assertEqual(category_for("Outfit Sets"), "other")


if __name__ == "__main__":
    unittest.main()
