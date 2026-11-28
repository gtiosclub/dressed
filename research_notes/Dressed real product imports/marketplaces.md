# eBay and Depop import access

## Can Dressed use eBay as a live product source?

### Takeaway
eBay is the strongest official marketplace connector of these two, conditional on production approval. Query-driven discovery and item refresh are a better initial fit than copying its full inventory.

### Cited Findings
- Browse supports keyword/category/GTIN/product/image search, item details and variation groups; application tokens use client credentials. [Browse API](https://developer.ebay.com/develop/api/buy/browse_api)
- Production Buy API access is partner-gated, requires application review and contracts, and approval is not guaranteed. The published process uses EPN business-model approval followed by developer review; sandbox availability does not establish production approval. [Buy requirements](https://developer.ebay.com/api-docs/buy/buy-requirements.html)
- Default Browse allowance is 5,000 calls/day for methods except getItems, with getItems separately listed at 5,000/day; Buy APIs need an additional license. This is request capacity, not a cost estimate. [Limits](https://developer.ebay.com/develop/api/buy/api_call_limits)
- Search is limited to 10,000 results per query; default results include fixed-price buying options. [Search reference](https://developer.ebay.com/develop/api/buy)
- Publicly displayed eBay content must be visually isolated from non-eBay listings; content no longer publicly available must be deleted from the application. Displayed listing information must be no more than six hours older than the eBay site, with age disclosed when older than the source. Other content has a 24-hour limit. [API license, section 8](https://developer.ebay.com/develop/api-license-agreement)
- Existing Dressed groundwork is a saved-response adapter into partial SQLite catalog feeds, not a network connector; user-shared HTTPS links reach manual review and local Wishlist. [Local catalog README](../../backend/catalog/README.md), verified by parent repository inspection.

### Inferences
- Reuse the existing response adapter after approved access, adding backend token management, bounded keyword/category calls, source-specific display, and refresh/expiry. Keep query results partial: absent search results do not prove a listing sold.
- A unified internal model does not imply permission for one visually mixed eBay/Pacsun/Depop grid. Design source-separated sections unless eBay grants a variation.
- Requiring every listing to be refreshed within six hours makes a giant permanent mirror impractical at starter limits; on-demand search and a small fresh cache are a better fit.

### Gaps
- No production credential, account-specific entitlement, or Dressed approval was tested. No promise of approval timing or live API pricing.
- Permanent user-owned closet copies of licensed listing media require separate examination; browse/display rights alone should not be interpreted as indefinite archival rights.

## Does Depop offer public marketplace discovery?

### Takeaway
The documented official API is private and seller-oriented. It is not a documented public whole-marketplace search source for Dressed.

### Cited Findings
- The official API overview explicitly calls the API private and unavailable to the general public; access is requested from Depop. It supports inventory, orders and offers. [Overview](https://partnerapi.depop.com/api-docs/)
- GET /api/v1/products/ returns products the connected seller has listed, up to 100 per page with cursor pagination. Product detail endpoints exist, but their presence is not permission for global catalog access. [Reference](https://partnerapi.depop.com/api-docs/reference/)
- October 2026 Terms section 7 prohibits mining, scraping/crawling, bots and unauthorized use or sharing of other users' content. [Terms](https://depophelp.zendesk.com/hc/en-gb/articles/360001773148-Terms-of-Service)
- API terms prohibit unauthorized automated access and collection for analytics/ML/training/licensing without written authorization. [API terms](https://partnerapi.depop.com/api-docs/terms/)

### Inferences
- Initial Depop support should be a user-saved source link with user-authored details and an outbound action, while pursuing a partnership for verified richer metadata. Saving a link is distinct from fetching and redistributing a seller's images/descriptions.
- Seller-supplied feeds/photos with permission can seed a curated resale subset, provided applicable Depop obligations are respected; this is seller participation, not access to the whole marketplace.
- A paid scraper vendor or browser agent does not itself solve authorization, image reuse, or freshness. Do not present a third-party scraping endpoint as an official API.

### Gaps
- No public buyer-search API was found in official documentation; absence of evidence is not proof that private commercial deals are impossible.
- Depop's Terms page includes future January 2027 sections before the currently applicable October 2026 section. The current finding above uses October wording; avoid quoting future LLM-specific language as current.

## What practical hybrid should Dressed adopt?

### Takeaway
Provide broad user-driven link capture now, one approved live discovery source next, and richer coverage through participating sellers or retailer feeds. Source access and a user's import confirmation remain separate steps.

### Cited Findings
- eBay supplies documented search/detail and a production approval route. [Browse](https://developer.ebay.com/develop/api/buy/browse_api), [access](https://developer.ebay.com/api-docs/buy/buy-requirements.html)
- Depop's documented integration serves connected sellers rather than public whole-marketplace retrieval. [Overview](https://partnerapi.depop.com/api-docs/), [reference](https://partnerapi.depop.com/api-docs/reference/)

### Inferences
- Recommend eBay as first marketplace access application and engineering spike, not as a guaranteed instantly available dependency. Demonstrate approved real search → select result → review → Wishlist, then repeat a detail refresh and verify sold/unavailable handling.
- Crowdsourcing should contribute canonical links, original tags and corrections, plus explicitly contributed images; private saves should not automatically become a publicly redistributed catalog.
- Keep listing identity distinct from underlying style/product identity: a sold Depop jacket is one seller's offer, not proof every matching jacket is unavailable.

### Gaps
- Pacsun and broad licensed feed/search providers are covered by other researchers.
