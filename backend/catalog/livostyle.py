"""Convert Livostyle's published open dataset into a local Dressed catalog feed."""

from __future__ import annotations

import argparse
import json
from decimal import Decimal, InvalidOperation
from pathlib import Path

from catalog import CatalogDatabase, canonical_json, validate_feed


DATASET_URL = ("https://raw.githubusercontent.com/arturayupov/"
               "womens-fashion-catalog-open-data/main/data/products.json")


def category_for(name: str) -> str:
    name = name.lower()
    if any(word in name for word in ("shoe", "sandal", "boot", "sneaker", "heel", "slipper")):
        return "shoes"
    if any(word in name for word in ("dress", "gown")):
        return "dresses"
    if "skirt" in name:
        return "skirts"
    if any(word in name for word in ("coat", "jacket", "blazer", "outerwear")):
        return "outerwear"
    if any(word in name for word in ("pant", "trouser", "jean", "short", "legging")):
        return "pants"
    if any(word in name for word in ("top", "shirt", "blouse", "sweater", "hoodie",
                                      "cardigan", "bodysuit", "sweatshirt")):
        return "tops"
    if any(word in name for word in ("ring", "earring", "belt", "bag", "necklace",
                                      "bracelet", "hat", "cap", "sunglass", "scarf")):
        return "accessories"
    return "other"


def exact_price_cents(value: object) -> int | None:
    if not isinstance(value, dict) or value.get("currency") != "USD":
        return None
    try:
        low = Decimal(str(value["min_usd"]))
        high = Decimal(str(value["max_usd"]))
    except (KeyError, InvalidOperation, ValueError):
        return None
    cents = low * 100
    if (not cents.is_finite() or low < 0 or low != high
            or cents != cents.to_integral_value()):
        return None
    return int(cents)


def convert_dataset(records: object, *, include_images: bool = False) -> dict:
    if not isinstance(records, list) or not records:
        raise ValueError("expected a non-empty Livostyle product array")
    if len(records) > 5000:
        raise ValueError("dataset exceeds local catalog limit")
    products = []
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"product {index} is not an object")
        external_id = record.get("id")
        if not isinstance(external_id, (str, int)) or isinstance(external_id, bool):
            raise ValueError(f"product {index} has no stable id")
        source_category = record.get("category")
        category_name = (source_category.get("name") if isinstance(source_category, dict)
                         else None)
        if not isinstance(category_name, str) or not category_name.strip():
            raise ValueError(f"product {index} has no category")
        product = {
            "externalId": str(external_id),
            "title": record.get("title"),
            "productURL": record.get("url"),
            "category": category_for(category_name),
            "sourceCategory": category_name,
        }
        price = exact_price_cents(record.get("price"))
        if price is not None:
            product.update(priceCents=price, currency="USD")
        variants = record.get("variants")
        if isinstance(variants, list) and variants:
            stocked = [variant.get("in_stock") for variant in variants
                       if isinstance(variant, dict)]
            if stocked and all(isinstance(value, bool) for value in stocked):
                product["availability"] = "inStock" if any(stocked) else "outOfStock"
        if include_images and record.get("featured_image_url"):
            product["imageURL"] = record["featured_image_url"]
        products.append(product)
    feed = {
        "source": {"id": "livostyle-open-data", "name": "Livostyle",
                   "allowedHosts": ["livostyle.com"], "imageHosts": ["cdn.shopify.com"]},
        "complete": True,
        "products": products,
    }
    validate_feed(feed)
    return feed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path, help="downloaded data/products.json")
    parser.add_argument("--db", type=Path, default=Path("/private/tmp/dressed-catalog.sqlite"))
    parser.add_argument("--feed-output", type=Path)
    parser.add_argument("--include-images", action="store_true",
                        help="include remote image URLs after confirming image use rights")
    args = parser.parse_args()
    feed = convert_dataset(json.loads(args.dataset.read_text()),
                           include_images=args.include_images)
    if args.feed_output:
        args.feed_output.write_text(json.dumps(feed, indent=2) + "\n")
    database = CatalogDatabase(args.db)
    try:
        summary = database.ingest(feed)
    finally:
        database.close()
    print(canonical_json(summary))


if __name__ == "__main__":
    main()
