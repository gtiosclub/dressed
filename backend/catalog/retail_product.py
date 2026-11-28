"""Serialize the shared Common/Models/RetailProduct.swift review contract."""

import hashlib


def from_metadata(metadata):
    fields = metadata["fields"]
    url = metadata["sourceURL"]
    result = empty_product("shared-link-html", url, url, metadata["extractedAt"])
    result.update(productURL=url, title=fields.get("title"), brand=fields.get("brand"),
                  description=fields.get("description"), sourceCategory=fields.get("category"),
                  identifiers=fields.get("identifiers", {}), attributes=fields.get("attributes", {}),
                  evidence=metadata["evidence"], warnings=metadata["warnings"],
                  variants=fields.get("variants", []))
    result["photos"] = photos(fields.get("imageURLs", [fields["imageURL"]] if fields.get("imageURL") else []), url)
    for raw in fields.get("offers", []):
        offer = empty_offer(metadata["extractedAt"])
        offer.update(raw)
        result["offers"].append(offer)
    return result


def from_candidate(candidate, observed_at):
    result = empty_product("serpapi", candidate["id"], candidate.get("comparisonURL"), observed_at)
    result.update(title=candidate.get("title"), brand=candidate.get("brand"),
                  description=candidate.get("description"), variantOptions=candidate.get("variantOptions", {}))
    result["photos"] = photos(candidate.get("imageURLs") or ([candidate["imageURL"]] if candidate.get("imageURL") else []), result["sourceURL"])
    for key in ("title", "photos"):
        result["evidence"][key] = {"method": "serpapi.google_shopping", "sourceURL": result["sourceURL"]}
    for key in ("brand", "description", "variantOptions"):
        if result[key]:
            result["evidence"][key] = {"method": "serpapi.immersive_product", "sourceURL": result["sourceURL"]}
    if candidate.get("imageURLs"):
        result["evidence"]["photos"]["method"] = "serpapi.immersive_product.thumbnails"
    for raw in candidate.get("offers", []) + candidate.get("pendingOffers", []):
        offer = empty_offer(observed_at)
        for key in ("merchant", "productURL", "redirectURL", "priceText", "availability", "variantVerified"):
            if key in raw:
                offer[key] = raw[key]
        result["evidence"][f"offers.{len(result['offers'])}"] = {
            "method": raw.get("evidence", "serpapi"), "sourceURL": raw.get("productURL") or raw.get("redirectURL")}
        result["offers"].append(offer)
    # Multiple stores are separate offers, never a fabricated canonical product URL.
    if len(result["offers"]) == 1:
        result["productURL"] = result["offers"][0]["productURL"]
    if not result["offers"]:
        result["warnings"].append("merchant_offer_missing")
    return result


def photos(urls, source_url):
    return [{"url": url, "sourceURL": source_url, "role": "primary" if i == 0 else "gallery",
             "reuseStatus": "unreviewed"} for i, url in enumerate(dict.fromkeys(urls))]


def empty_product(provider, identity, source_url, observed_at):
    return {"id": hashlib.sha256(f"{provider}\0{identity}".encode()).hexdigest()[:24],
            "schemaVersion": 1, "sourceURL": source_url, "productURL": None, "title": None,
            "brand": None, "description": None, "sourceCategory": None, "identifiers": {},
            "attributes": {}, "photos": [], "variants": [], "variantOptions": {}, "offers": [], "evidence": {},
            "warnings": [], "observedAt": observed_at, "requiresReview": True}


def empty_offer(observed_at):
    return {"merchant": None, "productURL": None, "redirectURL": None, "priceText": None,
            "amount": None, "lowPrice": None, "highPrice": None, "currency": None,
            "availability": "unknown", "condition": None, "observedAt": observed_at,
            "variantVerified": False}
