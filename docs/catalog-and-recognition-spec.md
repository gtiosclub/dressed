# Retail catalog and clothing recognition — proposed spec

**Status:** Proposal for lead review, updated October 18, 2026. A fixture-backed local SQLite catalog importer and read-only localhost API exist. Discovery Search calls the API and handles loading, empty, failure, and retry. An offline adapter converts saved eBay Browse search responses into partial catalog feeds; it does not call eBay. Camera supports reviewed product links saved locally to Wishlist, plus on-device garment suggestions. The Debug simulator can use a local bridge for live Google Object Localization after a developer signs in and receives access to the separate billed recognition project. Google Product Search still parses fixtures only. The app's `out-fitted` Firebase project remains unbilled. No live Product Search match, retailer crawler/feed, hosted recognition endpoint, or cloud deployment is implemented.

## Outcome and boundaries

Dressed should keep a **public catalog of products from selected retailers** and use a clothing photo to suggest garment categories and, later, visually similar catalog products. A catalog product is an offer from a retailer; a `ClothingItem` is an owned, private closet record. They never share a collection or record type. A visually similar result is not an exact product identification. Only a stable retailer product identifier, SKU/GTIN, or verified source link can support an “exact” label.

The first useful slice is one approved retailer source, a bounded set of current products, and a read-only catalog search page with source links. The recognition slice starts with the existing on-device Vision suggestion as a baseline, then tests a hosted detection API against the same review flow. Neither slice may put products into a user's closet without review and confirmation.

## A. Retail product catalog

### Source acquisition decision

Use a **source-specific connector** for each selected retailer. Prefer a licensed product feed or documented API. A page crawler is an option only for an allowlisted retailer after reviewing its applicable access, reuse, image, and refresh terms. The source record stores the allowed host/path set, acquisition method, rate limit, refresh interval, and whether Dressed may cache/display product images. Do not use search-engine snippets or arbitrary discovered domains as a product feed.

“Agentic” work is bounded to monitoring and repair assistance: detect a changed page layout, compare a sample against the last valid parse, and propose a parser update for review. The live ingestion job stays deterministic. If required fields disappear or the parser confidence drops, quarantine that batch and keep the last valid catalog state; an agent must not silently invent price, availability, identifiers, or purchase URLs.

An eBay Browse API connector is a possible **marketplace comparison**, not the selected-retailer default: its documented endpoints support keyword and image search and item detail, require an application token, and have call limits. A Shopify Storefront connector is possible for a participating shop with appropriate access. Neither grants general access to every retailer's catalog. See [eBay Browse](https://developer.ebay.com/develop/api/buy), [eBay API limits](https://developer.ebay.com/develop/api/buy/api_call_limits), and [Shopify Storefront authentication](https://shopify.dev/docs/api/storefront/latest).

### Ingestion pipeline

`scheduled source run → fetch allowed pages/feed → parse source fields → validate → normalize → upsert → mark unseen products stale → emit changed-product jobs`

1. A backend scheduler starts one run per source with a run ID and bounded page/item budget. A single source cannot fan out into other domains.
2. The connector uses conditional requests or source delta feeds where supported, obeys configured rate limits, and retries transient errors with backoff. Every run records fetched, parsed, accepted, rejected, and changed counts.
3. Validation requires a stable source product ID or approved canonical URL, title, source URL, and source identifier. Price, currency, brand, category, color, availability, and images are optional until verified. A product URL must point to the approved source host.
4. Normalize retailer categories into Dressed's category vocabulary while retaining the original label. Unknown categories remain `other`; no inferred field overwrites source-provided data without provenance.
5. Upsert by `(sourceId, externalProductId)` or a documented fallback canonical URL. Store `firstSeenAt`, `lastSeenAt`, `lastCheckedAt`, `sourceUpdatedAt?`, `contentHash`, and status. A rerun with the same input produces no duplicate products.
6. Mark missing products `stale` after one complete successful scan and `unavailable` after a second, source-configurable confirmation. Never infer an item is gone from a failed or partial scan. Refresh price and availability before surfacing them as current.
7. Only changed products trigger search-index or image-embedding work. Reuse source-hosted images or create derivatives only when the source policy permits it.

### Proposed backend records

These are **new public catalog records**, separate from the six-field `ClothingItem` and the owner-bound `ImportDraft`.

| Record | Required fields | Purpose |
| --- | --- | --- |
| `CatalogSource` | ID, retailer name, method, allowed hosts/paths, refresh/rate settings, image-use policy, enabled flag | A reviewed, bounded connector configuration |
| `CatalogProduct` | `id`, `sourceId`, external ID, title, canonical product URL, original category, normalized category, status, first/last seen and checked times, content hash | One retailer listing or variant with provenance |
| `CatalogOfferSnapshot` | product ID, observed time, price/currency?, availability?, source URL | Current offer state and a small audit history, retained for a defined period |
| `CatalogRun` | source ID, run ID, start/end, status, item counts, error summary, parser version | Diagnose freshness and parser drift |

Keep `CatalogProduct.id` deterministic from the source and external ID. If variants have distinct source IDs, retain them separately and relate them to a parent product; do not merge across retailers solely because photos look alike. Store `imageURL`, `brand`, color, material, size, and SKU/GTIN only with source provenance. A Firestore collection can serve the small prototype catalog because Firebase is already the proposed stack; evaluate full-text and vector search separately rather than assuming Firestore queries provide them. The iOS app receives a limited public DTO, never crawler credentials or internal run logs.

Proposed paths are `catalogProducts/{catalogProductId}` for active public product projections, `catalogSources/{sourceId}` and `catalogRuns/{runId}` for backend-only operations, and bounded offer history under each product. Backend identity alone writes these records. Client reads see only fields approved for public display. Define indexes for the actual category/status/freshness queries and a separate search service if text matching outgrows a bounded prototype dataset.

### Catalog API and first acceptance check

Backend-facing operations: `refreshSource(sourceId)`, `getRun(runId)`, and `listChangedProducts(since)`. App-facing operations: `searchCatalog(query, category?, cursor)` and `getCatalogProduct(id)`. Results include the retailer name, last checked time, source link, and an explicit `unavailable` state. A click opens the verified retailer URL; it does not create a closet item.

For the first source, ingest a bounded fixture and then an approved live source. Re-run the same feed twice and verify stable IDs/no duplicates. Change one price, remove one item in a complete run, and simulate one failed run: the changed price updates, removal follows the stale policy, and the failed run leaves the last valid records intact. Search results must never expose private closet media or another user's drafts.

## B. Clothing recognition and catalog matching

### Three separate tasks

| Task | Input → output | First implementation |
| --- | --- | --- |
| Garment classification | One image → suggested category/name | Existing on-device Apple Vision general image classifier plus Dressed keyword mapping; manual fallback |
| Garment detection | Outfit image → separate garment regions and categories | Evaluate a hosted object-localization or clothing-specific detector; return zero or more reviewable candidates |
| Catalog retrieval | Approved garment crop/description → ranked public catalog products | Start with category/text filters; add image embeddings only after a quality baseline |

The current Apple Vision path classifies the **whole image** and does not locate every garment. Cloud general-purpose baselines to evaluate include [Google Cloud Vision Object Localization](https://docs.cloud.google.com/vision/docs/object-localizer), which returns multiple rectangular object regions, and [Amazon Rekognition DetectLabels](https://docs.aws.amazon.com/rekognition/latest/dg/labels-detect-labels-image.html), which can include bounding boxes for common apparel labels. Neither documentation promises complete fashion segmentation or exact product identity. If those baselines miss garments, test a clothing-specific detection/segmentation model through a replaceable provider adapter. [Roboflow Inference](https://inference.roboflow.com/quickstart/roboflow_ecosystem/) is one hosted/self-hosted deployment option, contingent on model/data quality and its current terms.

**Recommended first API spike:** Google Cloud Vision Object Localization on a small, synthetic or consented image set. It directly tests whether a general hosted API returns separate boxes for clothing pieces. Compare its output with the existing on-device classifier and a manual gold standard before connecting it to the app. A Google Cloud project, billing setup, and an approved spend limit may be needed; the repository's Firebase dependencies do not provision this service.

The [fixture adapter](../backend/recognition/README.md) now parses Object Localization responses and uses the existing intersection-over-union evaluator. Its synthetic two-detection example is a contract check only; it is not evidence that the provider recognizes real outfits.

The [Product Search experiment](../backend/recognition/README.md) adds a second comparison path. It can return garment boxes and similar matches from a preloaded product set in one response, but those matches are limited to that set. The developer CLI displays Product Search and Object Localization candidate sets from one saved response. Its fixture test is not evidence of detection quality. The $5 monthly budget is an alert, not an enforceable cap. Billing and Vision are enabled on the separate recognition project for bounded Object Localization testing; Product Search has no live adapter or indexed product set.

### Recognition contract and privacy

`recognize(importId, privateImageRef) → RecognitionResult { provider, modelVersion, candidates[], status }`

Each candidate has a stable candidate ID, normalized bounding box or mask reference, suggested Dressed category/name, raw provider label, confidence, and preview crop reference. The service may return `noDetection`, `unsupportedImage`, `providerUnavailable`, or `timedOut`; all lead to editable manual review. Confidence is a ranking hint, not a calibrated probability or a reason to auto-save. The user selects/deselects candidates and confirms before any closet or wishlist write. Duplicate requests reuse the same import ID and candidate IDs.

Call hosted recognition through a backend adapter. Keep provider keys out of the iOS client, send only the minimum image needed, use a private temporary object with an expiry, and record provider retention/processing terms before using real user photos. The original shared image remains private. Recognition output is not a post and cannot publish media.

For catalog retrieval, filter to active products in the same category, rank text/attributes first, then test visual embeddings on approved product images. Show “Similar items” with the retailer source and last checked time. Show “Exact product” only when a verified identifier or source URL establishes identity. An image-only similarity score never creates a purchase link.

### Evaluation gate before provider choice

Create a consented/development image set, split by single-garment product photos, worn outfits, flat lays, overlapping garments, and difficult lighting. Annotate garment regions and the agreed Dressed categories. Compare Apple Vision, at least one generic hosted detector, and a clothing-specific option when available on the **same** held-out set. Record per-category detection recall/precision, category accuracy, no-detection rate, p95 latency, failure rate, and estimated cost per 1,000 images at the expected image size. Check how many candidate edits users need in review. Set acceptance thresholds after the baseline is measured; do not select a provider from a vendor demo alone.

The first end-to-end test uses one multi-garment image: detection returns separate candidate IDs, the user approves one and skips another, edits one category, confirms, and sees only approved pieces in the private closet. A no-detection image must still allow manual entry. Catalog matches remain a separate, clearly labeled Discovery result.

## Dependencies and open decisions for Neal

1. Name the first one or two retailers and confirm an API/feed or permitted crawl path, including product-image display rights. Until then, implement connector fixtures and the ingestion contract, not a live site crawler.
2. Decide the initial catalog geography/currency and whether variants (size/color) are separate results or grouped under one product.
3. Approve whether real user photos may be sent to a hosted recognition provider. Until then, use synthetic/consented development images and the on-device path.
4. Choose a spend ceiling for API calls, image processing, and storage before enabling scheduled live runs. Source API limits and provider prices can change; check current terms during selection.
5. Decide whether the first release needs garment **detection** from an outfit image or only a category suggestion for one garment. The former needs a measured detector and review UI; the latter is closer to the existing prototype.

## Sequencing

First, freeze the `CatalogSource`/`CatalogProduct` and recognition response contracts using fixtures. Next, connect one approved source and run it repeatedly with freshness/error checks. In parallel, assemble the recognition evaluation set and compare providers. Only after a provider passes the quality/privacy/cost gate should leads connect detection to `ImportDraft` review. Catalog matching follows once product coverage and freshness are sufficient to make its results useful.

For the next-Monday prototype target (October 19, 2026), the bounded result is: a repeatable one-source catalog import with stable IDs and stale-item handling; a read-only catalog result with verified retailer provenance; and a recognition comparison report using a small development image set. A live source depends on its access decision, and a hosted recognition run depends on the cloud/privacy/spend decision. Fixture-backed paths remain useful for demonstrating the contracts while those decisions are open.
