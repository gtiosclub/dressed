import unittest

from build_catalog_pack import color_of, gallery, record_for, select
from evaluate_catalog_pack import query_image, rank_of, summarize


def product(index, name="Blouses", title="White blouse", tags=()):
    return {"id": str(index), "title": title, "url": f"https://livostyle.com/products/p{index}",
            "category": {"name": name}, "tags": list(tags), "description": "Synthetic",
            "price": {"currency": "USD", "min_usd": 20, "max_usd": 20},
            "images": [{"url": f"https://cdn.shopify.com/s/{index}.jpg"}],
            "variants": [{"in_stock": True}]}


class CatalogPackTests(unittest.TestCase):
    def test_selection_caps_each_category_and_alternates_colors(self):
        records = [product(i, title="Black top") for i in range(20)]
        records += [product(100 + i, title="White top") for i in range(3)]
        chosen = select(records, {"tops": 6})
        colors = [color_of(record) for _, record in chosen]
        self.assertEqual(len(chosen), 6)
        self.assertEqual(colors.count("white"), 3)

    def test_selection_skips_unlisted_accessories_and_missing_images(self):
        wig = product(1, name="Keychains")
        bare = product(2, name="Hats")
        bare["images"] = []
        hat = product(3, name="Hats")
        chosen = select([wig, bare, hat], {"accessories": 5})
        self.assertEqual([record["id"] for _, record in chosen], ["3"])

    def test_gallery_only_allows_the_retailer_image_host(self):
        record = product(1)
        record["images"] += [{"url": "http://cdn.shopify.com/a.jpg"},
                             {"url": "https://example.com/a.jpg"}]
        self.assertEqual(gallery(record), ["https://cdn.shopify.com/s/1.jpg"])

    def test_record_uses_the_catalog_envelope_with_unreviewed_photos(self):
        value = record_for("tops", product(7), "2026-11-27T00:00:00Z")
        self.assertEqual(value["category"], "tops")
        self.assertEqual(value["status"], "needsReview")
        self.assertEqual(value["retailProduct"]["photos"][0]["reuseStatus"], "unreviewed")
        self.assertEqual(value["retailProduct"]["offers"][0]["amount"], "20.00")
        self.assertFalse(value["retailProduct"]["offers"][0]["variantVerified"])

    def test_rank_compares_only_within_the_category(self):
        products = [{"category": "tops"}, {"category": "tops"}, {"category": "shoes"}]
        vectors = [(1.0, 0.0), (0.9, 0.1), (1.0, 0.0)]
        self.assertEqual(rank_of(0, [1.0, 0.0], products, vectors), 1)
        self.assertEqual(rank_of(1, [1.0, 0.0], products, vectors), 2)

    def test_query_skips_the_indexed_photo_and_square_copies(self):
        source = {"cutoutSource": "a/front.jpg",
                  "gallery": ["a/front.jpg", "a/front-v2-square_1.webp", "a/back.jpg"]}
        self.assertEqual(query_image(source, False), "a/back.jpg")
        self.assertEqual(query_image(source, True), "a/front-v2-square_1.webp")
        self.assertIsNone(query_image({"cutoutSource": "a/front.jpg", "gallery": ["a/front.jpg"]}, False))

    def test_summary_applies_the_top_three_gate(self):
        report = summarize({"tops": [1, 3, 9], "shoes": [2]})
        self.assertEqual(report["overall"]["top3"], 0.75)
        self.assertTrue(report["gatePassed"])


if __name__ == "__main__":
    unittest.main()
