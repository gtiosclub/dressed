"""Resolve only captured Google /goto redirects; never fetch their destinations."""

import argparse
import copy
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, build_opener

from discovery_store import DEFAULT_ROOT, DiscoveryRun
from shopping_experiment import NoRedirect, google_result_url, merchant_url


class GoogleRedirectClient:
    def __init__(self, max_requests=3, opener=None):
        if not 0 <= max_requests <= 50:
            raise ValueError("max_redirects must be between 0 and 50")
        self.max_requests = max_requests
        self.requests = 0
        self.opener = opener or build_opener(NoRedirect())
        self.cache = {}

    def resolve(self, value):
        url = google_result_url(value, redirect=True)
        if not url:
            return {"status": "unsupported_redirect"}
        if url in self.cache:
            return self.cache[url]
        if self.requests >= self.max_requests:
            return {"status": "redirect_budget_exhausted"}
        self.requests += 1
        result = {"status": "unresolved", "checkedAt": datetime.now(timezone.utc).isoformat()}
        request = Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "text/html"})
        try:
            # NoRedirect raises HTTPError for 3xx; no request reaches the merchant.
            with self.opener.open(request, timeout=15) as response:
                result.update(status="no_http_redirect", httpStatus=response.status)
        except HTTPError as error:
            result["httpStatus"] = error.code
            location = error.headers.get("Location")
            error.close()
            target = merchant_url(urljoin(url, location)) if location else None
            if error.code in (301, 302, 303, 307, 308) and target:
                # Exclude Google-operated intermediaries as direct retailer URLs.
                host = urlsplit(target).hostname
                if host == "googleadservices.com" or host.endswith(".googleadservices.com"):
                    target = None
            if error.code in (301, 302, 303, 307, 308):
                result.update(status="resolved" if target else "unsupported_destination")
                if target:
                    result["productURL"] = target
            else:
                result["status"] = f"redirect_http_{error.code}"
        except (URLError, TimeoutError, OSError):
            result["status"] = "redirect_network_error"
        self.cache[url] = result
        return result


def resolve_candidates(query_result, resolve):
    """Preserve unresolved offers and provenance; resolution is not product verification."""
    for candidate in query_result["candidates"]:
        pending = []
        urls = {offer["productURL"] for offer in candidate["offers"]}
        for offer in candidate.get("pendingOffers", []):
            result = resolve(offer["redirectURL"])
            offer["urlResolution"] = result
            if result["status"] == "resolved":
                url = result["productURL"]
                if url not in urls:
                    offer["productURL"] = url
                    offer["id"] = hashlib.sha256(url.encode()).hexdigest()[:24]
                    offer["destinationVerified"] = False
                    candidate["offers"].append(offer)
                    urls.add(url)
            else:
                pending.append(offer)
        candidate["pendingOffers"] = pending
        if candidate["offers"]:
            candidate["resolution"] = "merchant_url_found"


def refresh_summary(report):
    candidates = [c for r in report["runs"] for c in r["candidates"]]
    offers = [o for c in candidates for o in c["offers"]]
    report["summary"].update(
        candidatesWithMerchantURL=sum(bool(c["offers"]) for c in candidates),
        uniqueMerchantURLs=len({o["productURL"] for o in offers}),
        offersWithPriceText=sum(bool(o["priceText"]) for o in offers),
        pendingRedirectOffers=sum(len(c.get("pendingOffers", [])) for c in candidates),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="saved live report with pendingOffers")
    parser.add_argument("--max-redirects", type=int, default=3)
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args()
    report = copy.deepcopy(json.loads(args.report.read_text()))
    if report.get("mode") not in ("live", "reprocessed_live", "resolved_live"):
        parser.error("requires a saved live report; synthetic fixture URLs must not be fetched")
    client = GoogleRedirectClient(args.max_redirects)
    archive = DiscoveryRun(root=args.data_dir, mode="live")
    print(f"Saving run to {archive.directory}", flush=True)
    try:
        for query in report["runs"]:
            resolve_candidates(query, lambda url: archive.capture("redirects", url, client.resolve))
            archive.record_query(query, observed_at=report["observedAt"])
        refresh_summary(report)
        report.update(mode="resolved_live", sourceRunId=report.get("runId"), requestAttempts=0,
                      redirectRequestAttempts=client.requests)
        path = archive.finish(report)
    except BaseException:
        archive.finish(status="interrupted")
        raise
    print(json.dumps({"reportPath": str(path), "redirectRequestAttempts": client.requests, **report["summary"]}))


if __name__ == "__main__":
    main()
