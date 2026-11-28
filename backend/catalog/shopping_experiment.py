"""Bounded shopping-search evaluation. No catalog writes or retailer fetching."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from discovery_store import DEFAULT_ROOT, DiscoveryRun, write_json

MAX_RESPONSE_BYTES = 2_000_000


def public_url(value):
    """Validate a display URL only; this is NOT a safe arbitrary-URL fetcher."""
    if not isinstance(value, str) or len(value) > 4096 or any(c.isspace() for c in value):
        return None
    try:
        parts = urlsplit(value)
        host = (parts.hostname or "").lower().rstrip(".")
        if (parts.scheme != "https" or parts.username or parts.password
                or parts.port not in (None, 443) or "." not in host
                or host.endswith((".localhost", ".local", ".internal"))
                or "\\" in value or "%" in host):
            return None
        try:
            ipaddress.ip_address(host)
            return None
        except ValueError:
            pass
        if all(c.isdigit() or c == "." for c in host):
            return None
        return urlunsplit(("https", host, parts.path, parts.query, ""))
    except ValueError:
        return None


def merchant_url(value):
    url = public_url(value)
    if not url:
        return None
    host = urlsplit(url).hostname
    if host == "serpapi.com" or host.endswith(".serpapi.com") or "google" in host.split("."):
        return None
    return url


def google_result_url(value, *, redirect=False):
    """Normalize observed Google result links; never label them merchant URLs."""
    if not isinstance(value, str):
        return None
    if redirect and value.startswith("/goto?"):
        value = "https://www.google.com" + value
    try:
        parts = urlsplit(value)
        if parts.hostname not in ("www.google.com", "google.com"):
            return None
        if redirect and (parts.path != "/goto" or not parts.query):
            return None
        # Only repair spaces in Google's query, not in authority/path or arbitrary URLs.
        if " " in parts.query:
            value = urlunsplit(parts._replace(query=parts.query.replace(" ", "%20")))
        return public_url(value)
    except ValueError:
        return None


def text(value, limit=1000):
    return value.strip()[:limit] if isinstance(value, str) and value.strip() else None


class ProviderError(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class SerpApiClient:
    def __init__(self, api_key, max_requests=1, opener=None):
        if not api_key:
            raise ValueError("Set SERPAPI_API_KEY in the backend environment")
        if not 1 <= max_requests <= 100:
            raise ValueError("max_requests must be between 1 and 100")
        self.api_key = api_key
        self.max_requests = max_requests
        self.requests = 0
        self.opener = opener or build_opener(NoRedirect())

    def request(self, **params):
        if self.requests >= self.max_requests:
            raise ProviderError("request_budget_exhausted")
        self.requests += 1  # Count attempts, including failed/possibly billed calls.
        query = urlencode({**params, "api_key": self.api_key})
        request = Request("https://serpapi.com/search.json?" + query,
                          headers={"Accept": "application/json"})
        try:
            with self.opener.open(request, timeout=20) as response:
                body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(body) > MAX_RESPONSE_BYTES:
                raise ProviderError("response_too_large")
            result = json.loads(body)
        except HTTPError as error:
            error.close()
            raise ProviderError(f"provider_http_{error.code}") from None
        except (URLError, TimeoutError, OSError):
            raise ProviderError("provider_network_error") from None
        except (ValueError, UnicodeError, RecursionError):
            raise ProviderError("invalid_provider_json") from None
        if not isinstance(result, dict) or result.get("error"):
            # Never emit provider errors/URLs: they may echo credentials.
            raise ProviderError("provider_response_error")
        return result

    def search(self, query):
        return self.request(engine="google_shopping", q=query, gl="us", hl="en")

    def details(self, token):
        return self.request(engine="google_immersive_product", page_token=token)


def offer(raw, title, source, method):
    raw_url = raw.get("link") or raw.get("product_link")
    url = merchant_url(raw_url)
    redirect = google_result_url(raw_url, redirect=True) if not url else None
    if not url and not redirect:
        return None
    return {
        "id": hashlib.sha256((url or redirect).encode()).hexdigest()[:24],
        "title": text(raw.get("title")) or title,
        "merchant": text(raw.get("name")) or source,
        "productURL": url,
        "redirectURL": redirect,
        "priceText": text(raw.get("price")),
        "availability": "unknown",
        "evidence": method,
        "destinationVerified": False,
        "variantVerified": False,
    }


def normalize_search(response, resolve=None, max_details=0, limit=10):
    if not isinstance(response, dict) or response.get("error"):
        raise ProviderError("provider_response_error")
    rows = response.get("shopping_results")
    information = response.get("search_information")
    if (rows is None and isinstance(information, dict)
            and information.get("shopping_results_state") == "Fully empty"):
        rows = []
    if not isinstance(rows, list):
        raise ProviderError("missing_shopping_results")
    candidates, seen, detail_count = [], set(), 0
    for raw in rows[:limit]:
        if not isinstance(raw, dict) or not text(raw.get("title")):
            continue
        title, source = text(raw["title"]), text(raw.get("source"))
        identity = text(raw.get("product_id")) or public_url(raw.get("product_link"))
        if not identity:
            continue
        if identity in seen:
            continue
        seen.add(identity)
        candidate = {
            "id": hashlib.sha256(identity.encode()).hexdigest()[:24],
            "title": title, "source": source,
            "comparisonURL": public_url(raw.get("product_link")) or google_result_url(raw.get("product_link")),
            "imageURL": public_url(raw.get("thumbnail")),
            "searchPriceText": text(raw.get("price")),
            "offers": [], "pendingOffers": [], "resolution": "unresolved",
        }
        direct = offer(raw, title, source, "shopping_result")
        if direct:
            candidate["offers" if direct["productURL"] else "pendingOffers"].append(direct)
        token = text(raw.get("immersive_product_page_token"), 20000)
        if not candidate["offers"] and token and resolve and detail_count < max_details:
            detail_count += 1
            try:
                detail = resolve(token)
                product = detail.get("product_results", {}) if isinstance(detail, dict) else None
                if isinstance(product, dict):
                    candidate["brand"] = text(product.get("brand"))
                    candidate["description"] = text(product.get("description"), 10000)
                    thumbnails = product.get("thumbnails", [])
                    if isinstance(thumbnails, list):
                        candidate["imageURLs"] = list(dict.fromkeys(
                            url for value in thumbnails[:30] if (url := public_url(value))))
                    groups = product.get("variants", [])
                    candidate["variantOptions"] = {}
                    if isinstance(groups, list):
                        for group in groups[:20]:
                            if not isinstance(group, dict) or not text(group.get("title")):
                                continue
                            items = group.get("items", [])
                            if isinstance(items, list):
                                names = [name for item in items[:100] if isinstance(item, dict)
                                         and (name := text(item.get("name")))]
                                if names:
                                    candidate["variantOptions"][text(group["title"])] = list(dict.fromkeys(names))
                stores = product.get("stores") if isinstance(product, dict) else None
                if not isinstance(stores, list):
                    raise ProviderError("missing_stores")
                urls = {o["productURL"] or o["redirectURL"] for o in candidate["offers"] + candidate["pendingOffers"]}
                for store in stores[:20]:
                    if not isinstance(store, dict):
                        continue
                    resolved = offer(store, title, None, "immersive_product.stores")
                    if resolved:
                        identity = resolved["productURL"] or resolved["redirectURL"]
                        if identity not in urls:
                            urls.add(identity)
                            candidate["offers" if resolved["productURL"] else "pendingOffers"].append(resolved)
            except ProviderError as error:
                candidate["resolution"] = str(error)
        if candidate["offers"]:
            candidate["resolution"] = "merchant_url_found"
        elif candidate["pendingOffers"] and candidate["resolution"] == "unresolved":
            candidate["resolution"] = "merchant_redirect_pending"
        candidates.append(candidate)
    return candidates


def evaluate(queries, search, resolve=None, max_details=0, limit=10, on_query=None):
    runs = []
    for query in queries:
        started = time.monotonic()
        run = {"query": query, "candidates": [], "error": None}
        try:
            run["candidates"] = normalize_search(search(query), resolve, max_details, limit)
        except ProviderError as error:
            run["error"] = str(error)
        run["latencyMs"] = round((time.monotonic() - started) * 1000)
        runs.append(run)
        if on_query:
            on_query(run)
    candidates = [c for run in runs for c in run["candidates"]]
    offers = [o for c in candidates for o in c["offers"]]
    return {
        "schemaVersion": 1, "observedAt": datetime.now(timezone.utc).isoformat(),
        "provider": "serpapi", "market": "us", "runs": runs,
        "summary": {
            "queries": len(runs), "failedQueries": sum(r["error"] is not None for r in runs),
            "candidates": len(candidates), "candidatesWithMerchantURL": sum(bool(c["offers"]) for c in candidates),
            "uniqueMerchantURLs": len({o["productURL"] for o in offers}),
            "candidatesWithImageURL": sum(bool(c["imageURL"]) for c in candidates),
            "offersWithPriceText": sum(bool(o["priceText"]) for o in offers),
            "pendingRedirectOffers": sum(len(c["pendingOffers"]) for c in candidates),
            "detailFailures": sum(c["resolution"] not in ("unresolved", "merchant_url_found", "merchant_redirect_pending") for c in candidates),
        },
        "humanReviewRequired": ["relevance", "destination", "price", "variant", "imageRights", "availability"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fixture", type=Path, help="replay query-keyed saved responses; no network")
    mode.add_argument("--live", action="store_true", help="make metered requests with SERPAPI_API_KEY")
    parser.add_argument("--queries", type=Path, required=True, help="JSON array of up to 20 query strings")
    parser.add_argument("--output", type=Path, help="optional extra report copy; every run is archived")
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_ROOT,
                        help="persistent local archive and discovery database directory")
    parser.add_argument("--max-requests", type=int, default=1)
    parser.add_argument("--details-per-query", type=int, choices=range(0, 6), default=0)
    parser.add_argument("--max-redirects", type=int, choices=range(0, 51), default=3,
                        help="Google-only redirect requests per live run; no retailer pages are fetched")
    args = parser.parse_args()
    queries = json.loads(args.queries.read_text())
    if (not isinstance(queries, list) or not 1 <= len(queries) <= 20
            or any(not isinstance(q, str) or not q.strip() or len(q) > 300 for q in queries)):
        parser.error("queries must contain 1–20 nonempty strings, at most 300 characters each")
    client = None
    if args.live:
        try:
            client = SerpApiClient(os.environ.get("SERPAPI_API_KEY"), args.max_requests)
        except ValueError as error:
            parser.error(str(error))
        search, resolve = client.search, client.details
    else:
        fixture = json.loads(args.fixture.read_text())
        def search(query):
            if query not in fixture.get("searches", {}):
                raise ProviderError("missing_fixture_query")
            return fixture["searches"][query]
        def resolve(token):
            if token not in fixture.get("details", {}):
                raise ProviderError("missing_fixture_detail")
            return fixture["details"][token]
    archive = DiscoveryRun(root=args.data_dir, mode="live" if args.live else "fixture",
                           secret=client.api_key if client else None)
    from merchant_redirects import GoogleRedirectClient, resolve_candidates
    redirect_client = GoogleRedirectClient(args.max_redirects)
    def record_query(query):
        if args.live:
            resolve_candidates(query, lambda url: archive.capture("redirects", url, redirect_client.resolve))
        archive.record_query(query)
    print(f"Saving run to {archive.directory}", flush=True)
    try:
        report = evaluate(queries, lambda q: archive.capture("searches", q, search),
                          lambda token: archive.capture("details", token, resolve),
                          args.details_per_query, on_query=record_query)
        report["mode"] = "live" if args.live else "fixture"
        report["requestAttempts"] = client.requests if client else 0
        report["redirectRequestAttempts"] = redirect_client.requests
        report_path = archive.finish(report, "completed_with_errors" if report["summary"]["failedQueries"] else "completed")
    except BaseException:
        archive.finish(status="interrupted")
        raise
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.output, archive.report)
    print(json.dumps({"mode": report["mode"], "requestAttempts": report["requestAttempts"],
                      "redirectRequestAttempts": redirect_client.requests,
                      "reportPath": str(report_path), "databasePath": str(archive.database), **report["summary"]}))
    if report["summary"]["failedQueries"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
