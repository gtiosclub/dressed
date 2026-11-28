# Shared links, crowdsourcing and agentic discovery

## How can Dressed import individual real products now?

### Takeaway

The strongest near-term architecture is URL-first: a user supplies a product link, Dressed attempts supported metadata enrichment, and the user reviews the result. This builds directly on the existing manual Wishlist flow; it does not require first copying whole retailer inventories.

### Cited Findings

- Schema.org Product provides structured product properties and JSON-LD examples with names, images, brand, identifiers and offers. Google's product documentation shows offers with price, currency, availability, condition and URL. These are extraction inputs when a page actually contains them, not a guarantee that every retailer supplies complete or accurate values. [Schema.org Product](https://schema.org/Product); [Google Product structured data](https://developers.google.com/search/docs/appearance/structured-data/product-snippet)
- Open Graph defines title, canonical URL and image URL metadata. It is useful for a basic link preview; its core fields do not establish price, stock or a specific selected variant. [Open Graph](https://ogp.me/)
- Diffbot's Product API accepts product pages and documents extracted fields including title, images, offer-price details, SKU, and beta availability/category fields. It is a concrete optional managed extractor, not evidence of permission or tested success on PacSun/Depop. [Diffbot Product API](https://www.diffbot.com/docs/extract/product)
- Dressed's current documented footholds are pasted/shared HTTPS URLs -> editable review -> explicitly confirmed local Wishlist, plus a separate fixture-backed SQLite catalog and iOS Discovery HTTP client. No retailer metadata/image fetch is currently implemented. [Local catalog README](../../backend/catalog/README.md); [Architecture](../../docs/architecture.md) (repository context confirmed by coordinator).

### Inferences

Recommended sequence, proposed rather than implemented:

1. Normalize the user URL and identify a source connector. Preserve variant identifiers; remove known tracking parameters without blindly dropping every query string.
2. Prefer an approved API/feed detail lookup. For supported permitted pages, parse Product/Offer JSON-LD; fall back to Open Graph for title/image preview; optionally use a managed extractor on an explicitly bounded source list.
3. Return partial metadata with field provenance, source URL, observed time, and missing fields. Do not fill absent prices, stock or product IDs with model guesses. Handle multiple offers and variants explicitly.
4. Keep the existing editable review and confirmation. If fetching is blocked or incomplete, preserve the link and allow manual details and a user-supplied image; never require bypassing a login or bot challenge.
5. Keep personal saves separate from shared catalog records. A private save is not automatic permission to republish its photos, and a successful fetch is not proof that redistribution or embedding is allowed.

A backend URL fetcher needs URL/redirect validation, private-network blocking, download/time limits and per-source budgets. These are implementation requirements for accepting arbitrary URLs, not a reason to delay the product decision.

### Gaps

No live sample success rate was measured for named retailers. No claim that PacSun or Depop currently exposes usable JSON-LD, accepts automated fetches, or grants image reuse can be made from schema documentation. Provider trials and account permissions remain to be tested.

## How should crowdsourcing grow useful coverage?

### Takeaway

Crowdsource discovery and corrections while retaining a distinction between a community-submitted reference and a verified current offer. Seller opt-in uploads can provide a better foundation for reusable images than copying photos from arbitrary third-party listings.

### Cited Findings

- Product identifiers, brand, category and offer information have standardized representations, supporting a shared normalization layer across submitted links and feed imports. [Schema.org Product](https://schema.org/Product)
- SearchApi explicitly says returned third-party content can require appropriate permission or a license, and its collection guarantee excludes customer use, storage and redistribution. This is concrete evidence that paying an extraction provider does not itself settle downstream content rights. [SearchApi terms](https://www.searchapi.io/legal/terms)

### Inferences

Suggested Dressed design:

- Start with a small voluntary club-curated set of favorite product links and user-written tags, rather than trying to crowdsource an entire global inventory.
- A submitted product retains canonical source URL, submitter, source/verification status, metadata timestamps and any media permission record. Dedupe by source listing ID or verified canonical URL. Never merge two one-off resale listings just because they depict the same garment model.
- Invite willing local sellers or small stores to upload their own catalog CSV and images with explicit permission for Dressed display. This is a separate opt-in intake channel, not automatic Depop-wide integration.
- Allow reports such as wrong category, duplicate, link broken and sold. Require evidence or a new source check before user edits change shared price/stock. User observations can be labeled as such.
- Private Wishlist saving should remain separate from an optional explicit public contribution. Image indexing/cutouts/redistribution need their own permitted scope; a contributor cannot necessarily grant rights to someone else's product photo.
- Target a bounded collection useful to Dressed's audience. For example, 20 volunteers submitting 15 unique links yields at most 300 initial candidates before deduplication; this is illustrative arithmetic, not measured yield.

### Gaps

No empirical participation, retention or moderation cost data for Dressed exists. Crowdsourcing alone cannot guarantee freshness, retailer breadth or photo rights. Public contribution policy and permission wording remain product/legal decisions.

## Where do background agents and search APIs help?

### Takeaway

Use agents to propose relevant searches, classify evidence-backed results and spot failures. Use deterministic connectors and explicit budgets for acquisition and updates. Search results can expand on-demand discovery, but they are not a complete licensed retailer feed.

### Cited Findings

- SerpApi Google Shopping returns titles, merchant source, price fields, thumbnails and product links. Its documented examples often use a Google Shopping URL for `product_link`, so it must not be assumed to be the direct merchant purchase URL. [SerpApi Shopping results](https://serpapi.com/shopping-results)
- SerpApi also documents a separate immersive-product endpoint; obtaining offer details can require follow-up retrieval. [Immersive Product API](https://serpapi.com/google-immersive-product-api)
- SerpApi currently lists 250 free searches monthly and $25/month for 1,000; successful calls count regardless of returned result count, while cached/error calls do not. [SerpApi pricing](https://serpapi.com/pricing)
- SearchApi documents an eBay search endpoint whose examples include listing IDs, direct eBay URLs, seller details, condition and other result fields. This is SearchApi's service, distinct from official eBay Browse access. [SearchApi eBay Search](https://www.searchapi.io/docs/ebay-search-api)
- SearchApi currently offers 100 free requests and a $40/month Developer tier with 10,000 searches. [SearchApi pricing](https://www.searchapi.io/pricing)
- SearchApi's terms place third-party content permissions on the customer and exclude customer redistribution from its legal protection guarantee. [SearchApi terms](https://www.searchapi.io/legal/terms)

### Inferences

Concrete trial: take 20 representative searches (specific brand/model, broad category, style phrase, resale listing) and compare a single shopping-search provider with user-submitted links. Measure named-merchant coverage, usable merchant URLs, correct variant/price, available images, result age, duplicates, latency and actual requests per usable product. Do not equate vendor network size with coverage available to Dressed.

A bounded background job could run saved searches like a particular style/category once per day, dedupe URLs, queue supported links for enrichment, and propose additions for review. An LLM may generate query variations and classify styles, but price, stock, identifiers and URLs must come from source evidence. Scheduled searches should be opt-in and obey provider/source retention and refresh rules.

Illustrative economics: 20 searches/day for 30 days = 600 base requests/month, before pagination, offer-detail fetches, retries and model costs. That fits SerpApi's 1,000-search paid tier but not its free allowance. If every base query causes five detail requests, the same trial becomes 3,600 requests. These are arithmetic scenarios, not a quote or benchmark. Broad autonomous browsing adds variable model/browser costs; feeds avoid repeated page reasoning for bulk refresh when available.

Recommendation: extend URL enrichment first; add one bounded on-demand search trial for breadth; pursue approved feeds for durable catalog storage; use agents as curators and maintenance assistants. Do not make passive autonomous crawling the dependency for the first useful real-product import.

### Gaps

No paid provider calls, credentials, or live result coverage tests were performed. No verified all-retailer search completeness or universal rights grant was found. SearchApi/SerpApi should be evaluated as retrieval services, and merchant-direct URL resolution is an explicit test criterion.
