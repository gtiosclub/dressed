"""Convert a saved eBay Browse search response into a partial Dressed feed.

This adapter deliberately has no network path. Production Browse API access and
spending controls must be reviewed before a live connector is enabled.
"""

from __future__ import annotations

import argparse
import json
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import urlsplit

from catalog import CATEGORIES, CatalogDatabase, canonical_json


PRODUCT_HOSTS = {"ebay.com", "www.ebay.com"}
IMAGE_HOSTS = {"i.ebayimg.com"}
MAX_ITEMS = 100


def _approved_url(value: object, hosts: set[str]) -> str | None:
    if not isinstance(value, str) or len(value) > 4096:
        return None
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError:
        return None
    if (parsed.scheme != "https" or (parsed.hostname or "").lower() not in hosts
            or parsed.username or parsed.password or port not in (None, 443)):
        return None
    return value


def _price_cents(price: object) -> tuple[int, str] | None:
    if not isinstance(price, dict):
        return None
    currency = price.get("currency")
    if not isinstance(currency, str) or len(currency) != 3 or not currency.isalpha():
        return None
    try:
        amount = Decimal(str(price["value"]))
    except (KeyError, InvalidOperation, ValueError):
        return None
    cents = amount * 100
    if not cents.is_finite() or cents < 0 or cents != cents.to_integral_value():
        return None
    return int(cents), currency.upper()


def convert_response(response: object, *, category: str = "other") -> tuple[dict, int]:
    """Return a partial feed and the number of entries excluded as invalid."""
    if category not in CATEGORIES:
        raise ValueError("unknown Dressed category")
    if not isinstance(response, dict):
        raise ValueError("expected a Browse response with itemSummaries")
    summaries = response.get("itemSummaries", [] if response.get("total") == 0 else None)
    if not isinstance(summaries, list):
        raise ValueError("expected a Browse response with itemSummaries")
    if len(summaries) > MAX_ITEMS:
        raise ValueError(f"response exceeds {MAX_ITEMS} items")

    products = []
    seen = set()
    skipped = 0
    for raw in summaries:
        if not isinstance(raw, dict):
            skipped += 1
            continue
        item_id = raw.get("itemId")
        title = raw.get("title")
        product_url = _approved_url(raw.get("itemWebUrl"), PRODUCT_HOSTS)
        if (not isinstance(item_id, str) or not item_id.strip() or len(item_id) > 200
                or item_id in seen or not isinstance(title, str) or not title.strip()
                or not product_url):
            skipped += 1
            continue
        seen.add(item_id)
        product = {
            "externalId": item_id,
            "title": title.strip(),
            "productURL": product_url,
            "category": category,
            "availability": "unknown",
        }
        image = raw.get("image")
        if isinstance(image, dict):
            image_url = _approved_url(image.get("imageUrl"), IMAGE_HOSTS)
            if image_url:
                product["imageURL"] = image_url
        price = _price_cents(raw.get("price"))
        if price:
            product["priceCents"], product["currency"] = price
        categories = raw.get("categories")
        if isinstance(categories, list) and categories and isinstance(categories[0], dict):
            source_category = categories[0].get("categoryName")
            if isinstance(source_category, str) and source_category.strip():
                product["sourceCategory"] = source_category.strip()
        products.append(product)

    feed = {
        "source": {
            "id": "ebay-us-browse",
            "name": "eBay US Browse",
            "allowedHosts": sorted(PRODUCT_HOSTS),
            "imageHosts": sorted(IMAGE_HOSTS),
        },
        # A keyword result is never the full catalog. Missing items must not age out.
        "complete": False,
        "products": products,
    }
    return feed, skipped


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("response_file", type=Path, help="saved Browse response JSON; no API call")
    parser.add_argument("--category", choices=sorted(CATEGORIES), default="other")
    parser.add_argument("--db", type=Path, default=Path("/private/tmp/dressed-catalog.sqlite"))
    parser.add_argument("--feed-output", type=Path, help="optional converted feed JSON")
    args = parser.parse_args()

    feed, skipped = convert_response(json.loads(args.response_file.read_text()), category=args.category)
    if args.feed_output:
        args.feed_output.write_text(json.dumps(feed, indent=2, sort_keys=True) + "\n")
    database = CatalogDatabase(args.db)
    try:
        summary = database.ingest(feed)
    finally:
        database.close()
    print(canonical_json({"catalog": summary, "skipped": skipped}))


if __name__ == "__main__":
    main()
