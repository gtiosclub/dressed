# Product link reader (P19 prototype)

Reads a known product link on the backend and returns a **draft** for review. Nothing here saves to Wishlist; the app saves only fields the person confirms. This is a developer prototype, not a deployed or authenticated service.

## What it does

`reader.py`: https-only link check, private-address blocking (re-checked on every redirect), size and time caps, plain GET with an identifying user agent (no proxy rotation, no stealth). Extractors run in order: JSON-LD, Microdata, Open Graph. Each field is `{value, source, evidence, state}` with state `from_page`, `from_link`, `suggested` or `open`.

Fill rules:
- Name, image, retailer: from the page; retailer falls back to the link's domain, labeled `from_link`.
- Category: only an exact match to a known category. Anything else is a `suggested` value with no fill. The Dressed category list is still TBD; the map matches the app's current `ClothingCategory` values.
- Price: only one unambiguous offer with a stated currency. Several offers, a missing currency or a script-set price leaves it open.
- Availability: only from that single offer.
- Variant: only from a `variant=` parameter in the link. Otherwise open.
- 401, 403, 429 or a bot-wall page: status `blocked`, never retried or routed around. Timeouts: `failed`. Both keep the link.

## Run

From the repository root, with no network or account:

```sh
python3 -m unittest discover -s backend/links
python3 backend/links/local_service.py --fixture backend/links/fixtures/jacket-jsonld.html
python3 backend/links/benchmark.py backend/links/fixtures/synthetic-manifest.json
```

The service listens on `127.0.0.1:8767` only. `POST /product-imports {"url", "clientRequestId"}` returns a draft; the same `clientRequestId` returns the same draft, so a retry creates nothing new. `GET /product-imports/{importId}` reads one. A physical iPhone cannot reach this loopback address.

## Benchmark

`benchmark.py` scores each field as correct, wrong, missing, correctly open, or wrongly filled, and reports p50/p95 time. The bundled manifest uses **synthetic** pages written for these tests; its numbers check the scoring, not real-store accuracy. For the real 30-link run, write a manifest with hand-checked `expected` values and either a saved `snapshot` or no snapshot for a live fetch. List only stores whose terms and robots rules allow it. Measured results for real stores: not run yet.
