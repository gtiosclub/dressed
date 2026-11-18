"""Extract review suggestions from supplied HTML; never fetch a retailer page."""

import argparse
import json
import hashlib
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit

from shopping_experiment import public_url, text
from discovery_store import DEFAULT_ROOT, DiscoveryRun, write_json


class MetadataParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.meta = {}
        self.images = []
        self.blocks = []
        self.current = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta":
            key = attrs.get("property") or attrs.get("name")
            if key and key not in self.meta:
                self.meta[key] = attrs.get("content")
            if key == "og:image" and attrs.get("content"):
                self.images.append(attrs["content"])
        if tag == "script" and attrs.get("type", "").lower() == "application/ld+json":
            self.current = []

    def handle_data(self, data):
        if self.current is not None:
            self.current.append(data)

    def handle_endtag(self, tag):
        if tag == "script" and self.current is not None:
            self.blocks.append("".join(self.current))
            self.current = None


def products(value):
    """Only top-level or @graph products, not unrelated recommendation trees."""
    nodes = value if isinstance(value, list) else [value]
    for node in nodes:
        if not isinstance(node, dict):
            continue
        kinds = node.get("@type", [])
        kinds = kinds if isinstance(kinds, list) else [kinds]
        if any(k in ("Product", "ProductGroup", "https://schema.org/Product", "http://schema.org/Product") for k in kinds):
            yield node
        graph = node.get("@graph")
        if isinstance(graph, list):
            yield from products(graph)


def image_urls(value, source_url):
    values = value if isinstance(value, list) else [value]
    urls = []
    for image in values[:30]:
        image = image.get("url") or image.get("contentUrl") if isinstance(image, dict) else image
        if isinstance(image, str):
            url = public_url(urljoin(source_url, image))
            if url and url not in urls:
                urls.append(url)
    return urls


def amount(value):
    if isinstance(value, bool) or not isinstance(value, (str, float, int)):
        return None
    try:
        number = Decimal(str(value))
        return str(number) if number.is_finite() and number >= 0 else None
    except InvalidOperation:
        return None


def attributes(value):
    return {key: text(value[key]) for key in ("color", "size", "material", "pattern", "gender")
            if text(value.get(key))}


def extracted_offers(value, source_url):
    values = value if isinstance(value, list) else [value]
    result = []
    for raw in values[:50]:
        if not isinstance(raw, dict):
            continue
        kind = raw.get("@type", "Offer")
        if kind not in ("Offer", "AggregateOffer", "https://schema.org/Offer", "https://schema.org/AggregateOffer"):
            continue
        seller = raw.get("seller")
        currency = text(raw.get("priceCurrency"))
        currency = currency.upper() if currency and len(currency) == 3 and currency.isascii() and currency.isalpha() else None
        availability = raw.get("availability")
        state = {"https://schema.org/InStock": "inStock", "https://schema.org/OutOfStock": "outOfStock",
                 "http://schema.org/InStock": "inStock", "http://schema.org/OutOfStock": "outOfStock"}.get(availability) if isinstance(availability, str) else None
        url = raw.get("url")
        result.append({"merchant": text(seller.get("name") if isinstance(seller, dict) else seller),
                       "productURL": public_url(urljoin(source_url, url)) if isinstance(url, str) else None,
                       "amount": amount(raw.get("price")) if kind.endswith("Offer") and not kind.endswith("AggregateOffer") else None,
                       "lowPrice": amount(raw.get("lowPrice")), "highPrice": amount(raw.get("highPrice")),
                       "currency": currency, "availability": state or "unknown",
                       "condition": text(raw.get("itemCondition")), "variantVerified": False})
    return result


def extract_metadata(html, source_url):
    url = public_url(source_url)
    if not url:
        raise ValueError("source URL must be a public HTTPS link")
    if len(html.encode("utf-8")) > 2_000_000:
        raise ValueError("HTML exceeds 2 MB limit")
    parser = MetadataParser()
    parser.feed(html)
    found, warnings = [], []
    for block in parser.blocks:
        try:
            found.extend(products(json.loads(block)))
        except (ValueError, RecursionError):
            warnings.append("invalid_json_ld")
    # Prefer an explicitly matching source URL; never pick the first recommendation.
    matching = [product for product in found if isinstance(product.get("url"), str)
                and public_url(urljoin(url, product["url"])) == url]
    if len(matching) == 1:
        found = matching
    if len(found) > 1:
        warnings.append("multiple_products_require_selection")
    selected = found[0] if len(found) == 1 else {}
    fields, evidence = {}, {}

    def put(key, value, origin):
        if value is not None:
            fields[key] = value
            evidence[key] = {"method": origin, "sourceURL": url}

    put("title", text(selected.get("name")), "json_ld.Product.name")
    put("category", text(selected.get("category")), "json_ld.Product.category")
    put("description", text(selected.get("description"), 10000), "json_ld.Product.description")
    identifiers = {key: text(selected.get(key)) for key in ("sku", "gtin", "gtin8", "gtin12", "gtin13", "gtin14", "mpn", "productID")
                   if text(selected.get(key))}
    if identifiers:
        put("identifiers", identifiers, "json_ld.Product.identifiers")
    if attributes(selected):
        put("attributes", attributes(selected), "json_ld.Product.attributes")
    # Retain the source category verbatim; mapping to ClothingCategory is later.
    brand = selected.get("brand")
    put("brand", text(brand.get("name") if isinstance(brand, dict) else brand), "json_ld.Product.brand")
    image = selected.get("image")
    image = image[0] if isinstance(image, list) and image else image
    image = image.get("url") if isinstance(image, dict) else image
    if isinstance(image, str):
        put("imageURL", public_url(urljoin(url, image)), "json_ld.Product.image")
    gallery = image_urls(selected.get("image"), url)
    if gallery:
        put("imageURLs", gallery, "json_ld.Product.image")
    variants = selected.get("hasVariant")
    if isinstance(variants, list):
        variants = [{"sourceId": text(v.get("sku")) or text(v.get("productID")), "title": text(v.get("name")),
                     "productURL": public_url(urljoin(url, v["url"])) if isinstance(v.get("url"), str) else None,
                     "attributes": attributes(v), "imageURLs": image_urls(v.get("image"), url), "selected": False}
                    for v in variants[:50] if isinstance(v, dict)]
        if variants:
            put("variants", variants, "json_ld.ProductGroup.hasVariant")
            warnings.append("variant_selection_required")
    offer_records = extracted_offers(selected.get("offers"), url)
    if offer_records:
        put("offers", offer_records, "json_ld.Product.offers")
    offers = selected.get("offers")
    if isinstance(offers, list):
        offers = offers[0] if len(offers) == 1 else None
        if offers is None:
            warnings.append("multiple_offers_require_selection")
    if isinstance(offers, dict) and offers.get("@type") in (None, "Offer"):
        # Preserve explicit strings; no price/range/currency inference.
        price = offers.get("price")
        if isinstance(price, (str, int, float)) and not isinstance(price, bool):
            try:
                number = Decimal(str(price))
                if number.is_finite() and number >= 0:
                    put("price", str(price), "json_ld.Offer.price")
            except InvalidOperation:
                pass
        put("currency", text(offers.get("priceCurrency")), "json_ld.Offer.priceCurrency")
        availability = offers.get("availability")
        states = {"https://schema.org/InStock": "inStock", "https://schema.org/OutOfStock": "outOfStock",
                  "http://schema.org/InStock": "inStock", "http://schema.org/OutOfStock": "outOfStock"}
        if isinstance(availability, str):
            put("availability", states.get(availability), "json_ld.Offer.availability")
    if len(found) <= 1:
        if "title" not in fields:
            put("title", text(parser.meta.get("og:title")), "open_graph.og:title")
        if "imageURL" not in fields and isinstance(parser.meta.get("og:image"), str):
            put("imageURL", public_url(urljoin(url, parser.meta["og:image"])), "open_graph.og:image")
        if "imageURLs" not in fields:
            gallery = image_urls(parser.images, url)
            if gallery:
                put("imageURLs", gallery, "open_graph.og:image")
        if "description" not in fields:
            put("description", text(parser.meta.get("og:description"), 10000), "open_graph.og:description")
        put("retailer", text(parser.meta.get("og:site_name")), "open_graph.og:site_name")
    return {"sourceURL": url, "extractedAt": datetime.now(timezone.utc).isoformat(),
            "fields": fields, "evidence": evidence,
            "warnings": sorted(set(warnings)), "requiresReview": True,
            "variantVerified": False, "status": "suggestions" if fields else "manual_required"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("html", type=Path)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", type=Path, help="optional additional copy of extracted metadata")
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--fixture", action="store_true", help="keep synthetic input out of the live database")
    args = parser.parse_args()
    if args.html.stat().st_size > 2_000_000:
        parser.error("HTML exceeds 2 MB limit")
    archive = DiscoveryRun(root=args.data_dir, mode="fixture" if args.fixture else "live")
    try:
        result = archive.capture("links", args.url, lambda url: extract_metadata(args.html.read_text(), url))
        candidate = {"id": hashlib.sha256(result["sourceURL"].encode()).hexdigest()[:24],
                     "title": result["fields"].get("title"), "sourceURL": result["sourceURL"],
                     "offers": [], "reviewState": "needs_metadata" if result["status"] == "manual_required" else "needs_verification",
                     "metadata": result}
        archive.record_query({"query": result["sourceURL"], "candidates": [candidate]},
                             provider="shared-link-html")
        path = archive.finish({"mode": archive.mode, "metadata": result})
    except ValueError as error:
        archive.finish(status="failed")
        parser.error(str(error))
    except BaseException:
        archive.finish(status="interrupted")
        raise
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.output, result)
    print(json.dumps({"status": result["status"], "reportPath": str(path), "databasePath": str(archive.database)}))


if __name__ == "__main__":
    main()
