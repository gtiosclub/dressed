# Dressed catalogue ingestion architecture

## What is already built, and what is missing?

### Takeaway
The repository has a useful offline ingestion seam: a reviewed JSON feed is validated and upserted into SQLite, then a read-only API serves Discovery Search. There is no live retailer fetcher or production catalogue service yet.

### Cited Findings
- `backend/catalog/catalog.py` accepts a source plus products, validates the entire feed before mutation, derives deterministic product IDs from source and external IDs, and ages out missing products only after complete scans. Its source host allowlist is currently supplied by the input feed itself. — [Catalogue implementation](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/catalog.py)
- The existing backend is explicitly loopback-only; its README says it makes no retailer request, is not deployed, and requires moving approved source configuration outside untrusted feeds before live connection. — [Catalogue README](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/README.md)
- An offline eBay Browse response converter maps saved responses into partial feeds; it has no token, fetch, or schedule path. — [eBay adapter](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/ebay_browse.py); [Catalogue README](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/README.md)
- The product spec calls for one approved source and a bounded catalogue with provenance, and says crawling is an option only after reviewing access, image and refresh terms. — [Catalogue spec](https://github.com/gtiosclub/dressed/blob/main/docs/catalog-and-recognition-spec.md)

### Inferences
- The first engineering task should be a **trusted source registry** outside feed payloads. A connector should emit a candidate feed; the registry should determine permissible source ID, product/image hosts and paths, acquisition method, image policy, request budget and refresh interval. Without this change, a feed can declare its own hosts approved.
- Keep `CatalogProduct` separate from six-field private `ClothingItem`. The iOS view can consume the existing public result DTO; catalogue import does not need to write a user's closet or alter the Camera review flow.

### Gaps
- No source has been selected or granted catalogue/image reuse rights in the repo. Hosting, budget, and geographic scope are undecided.

## How should live acquisition and agent assistance work?

### Takeaway
Use a deterministic source-specific fetcher and parser for production runs. An agent can inspect parse failures and propose a patch or mapping, but its unreviewed output should never become published product facts.

### Cited Findings
- The project spec explicitly defines a source-specific connector, bounded fetch/parse/validate/upsert flow and quarantining of low-confidence batches; it limits agentic work to monitoring and repair proposals. — [Catalogue spec](https://github.com/gtiosclub/dressed/blob/main/docs/catalog-and-recognition-spec.md)
- The Robots Exclusion Protocol specifies crawler behavior but says its rules are **not access authorization**. — [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html)
- HTTP `If-None-Match` and `If-Modified-Since` support conditional GETs and unchanged responses without retransmitting full representations. — [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html)
- OWASP recommends destination allowlisting and warns that domain allowlisting alone does not stop DNS rebinding; redirects and resolved destinations need their own checks. — [OWASP SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- Product pages can provide structured data with price and availability, but Google's documentation describes this as data for Google Search presentation; the presence of markup is not a grant to reuse it. — [Google Search Central](https://developers.google.com/search/docs/appearance/structured-data/product)

### Inferences
- Acquisition preference: direct licensed feed or official API; if the source explicitly permits crawling, use fixed seed pages and allowed product paths, strict host checks on redirects, ETag/Last-Modified where supported, rate limits, timeouts, and a small daily item budget. Never let an LLM choose arbitrary URLs or bypass a block.
- Parse structured product fields deterministically. A human-reviewed parser version should produce a candidate batch with source ID, observed timestamp, input hash, stable product ID, URL, title, optional price/currency, optional image URL, and provenance for each field. Reject unknown hosts and malformed records before upsert.
- On layout change, the agent receives a *small saved sample* and last successful parse, then writes a proposed selector/JSON-LD mapping and explanation. Regression fixtures and a human review precede a new parser version. Keep the last valid catalogue state when a batch fails validation.
- Do not cache or proxy images unless the source agreement allows it. A permitted hotlink or an image-free result is a distinct decision; neither follows merely from a publicly accessible image URL.

### Gaps
- Source-specific terms determine whether any page crawling, image display, and refresh are allowed. Robots alone cannot settle those questions.

## What is a concrete first pilot and acceptance gate?

### Takeaway
Pilot **one authorized source**, one geography, one category or a small fixed category set, and a bounded product count. Validate repeated imports, stale handling, price freshness, and public links before adding more retailers or visual matching.

### Cited Findings
- The current importer limits a feed to 5,000 products, supports active/stale/unavailable states, and the read API returns source, price, availability, URL, and last checked time. — [Catalogue implementation](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/catalog.py)
- The existing tests cover repeat import, changed price, failed-feed isolation, partial-versus-complete ageing, and a loopback HTTP search endpoint. — [Catalogue tests](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/test_catalog.py)
- The spec asks Neal to settle first retailers, geography/currency, variants, and a spending ceiling before live scheduled runs. — [Catalogue spec](https://github.com/gtiosclub/dressed/blob/main/docs/catalog-and-recognition-spec.md)

### Inferences
- **Phase 0 — source decision:** record for each candidate the official access path, permitted fields/images, retention and refresh rules, geography, rate/cost ceiling, and contact/approval evidence. Select a source with a feed/API or explicit crawl permission. If none qualifies, keep Discovery Search fixture-only and pursue a participating retailer.
- **Phase 1 — offline connector:** move source policy out of feed input; add a saved real-shaped response fixture and pure converter; classify keyword/paginated samples as `complete: false`; add negative fixtures for URLs, redirects, prices, duplicates, missing identifiers and parser drift. No website requests or deployment in this phase.
- **Phase 2 — controlled live pilot:** server-side credentials only; one run per source with a hard page/item/request budget, pagination bounds, retry/backoff, cursor checkpoints, run logs and a dry-run/quarantine path. Compare a sample of products with their final source pages, including title, price, currency, stock and image use. Failed or partial scans must not mark listings unavailable.
- **Phase 3 — public serving:** serve approved fields from an authenticated backend or a public projection, never the local dev HTTP server. Filter stale/unavailable and age-expired offers, show retailer and last-check time, and open only verified allowed final links. Measure sample accuracy and refresh latency before widening coverage.
- **Phase 4 — agent-assisted maintenance:** alert on reject-rate or field-loss spikes, have an agent draft a parser change against stored samples, require a human review and fixture pass before promotion. Agents do not invent identifiers, price or stock.
- Suggested release gate: two repeat successful bounded runs with stable IDs; zero unapproved final hosts; no stale/unavailable leakage; known prices/availability checked against a reviewed sample; explicit handling of redirects, 429, malformed payload and incomplete pagination; a rollback to last valid results.

### Gaps
- No source-specific service agreement, refresh SLA, cost budget or live endpoint is currently established. Numerical quality thresholds should be agreed before connecting a source rather than inferred from fixture tests.
