# Commercial cross retailer product APIs

## Which products offer a ready made multi retailer catalogue?

### Takeaway
Firmly and CartAI advertise cross merchant product discovery APIs, while Lykdat offers search over its own fashion product catalogue. None of the reviewed public documentation establishes that a Dressed account would receive PacSun, Hollister, Depop, or Vinted specifically.

### Cited Findings
- Firmly's Discovery API searches multiple merchant catalogues, returns product URLs, brand, prices, and filters; results are restricted to merchants authorized for the customer's App ID. Its index refreshes on a schedule, and the docs advise a fresh Catalog lookup for price and stock. — [Firmly Discovery](https://developers.firmly.ai/api-reference/discovery/); [Firmly Search Products](https://developers.firmly.ai/api-reference/discovery/search/)
- CartAI documents a `/product/search` endpoint for search across its merchant network, including Shopify stores and major retailers, with pricing, images, and direct purchase links. — [CartAI Search Products](https://docs.cartai.ai/reference/search_products)
- Lykdat's `/global/search` accepts a fashion image and searches Lykdat's product catalogues without creating one's own. It requires a business account and API key. This is image similarity discovery, rather than a documented bulk product feed. — [Lykdat API docs](https://apidocs.lykdat.com/)
- Fashion Cloud provides brand product data, images, and retailer specific stock through an API, but API access is enabled by request and each brand controls permissions. Its business is wholesale fashion; it says it serves 700 brands and 30,000 retailers in Europe. — [Fashion Cloud API](https://docs.api.fashion.cloud/); [Fashion Cloud platform](https://www.fashion.cloud/)

### Inferences
- Firmly is the closest technical match for live cross retailer search, contingent on merchant access and commercial terms. Lykdat deserves a separate evaluation for Dressed's later photo similarity feature, not as the main ingestion source.

### Gaps
- Public docs do not confirm the four requested retailers' presence, exact coverage, product/image redistribution or caching rights, commercial pricing for Dressed, or API approval.
- No currently supported public ShopStyle/Collective Voice developer product API was verified from official sources in this review; its creator product tools should not be assumed to be a developer feed.

## Are extraction and price data APIs equivalent to licensed catalogue feeds?

### Takeaway
No. Diffbot, DataWeave, and Price API provide structured data extraction or price intelligence; their technical ability to retrieve a product page does not establish permission for Dressed to republish a retailer's catalogue or images.

### Cited Findings
- Diffbot's Product API extracts title, brand, price, availability, SKU/GTIN, and image URLs from a submitted product page. Extract processes a supplied URL; its Bulk Extract documentation says Bulk is not a crawler and requires supplied URLs. — [Diffbot Product API](https://www.diffbot.com/docs/extract/product); [Diffbot Bulk Extract](https://www.diffbot.com/products/extract/bulk)
- Diffbot's Extract charges a base credit per page, two when proxying; its pricing page describes a free monthly credit pool and paid plans. — [Diffbot Extract](https://www.diffbot.com/docs/extract/); [Diffbot pricing](https://www.diffbot.com/pricing)
- DataWeave's Data Collection API describes custom crawling algorithms that extract product details, pricing, images, and availability; this is on demand extraction rather than a documented licensed retailer feed. — [DataWeave Data Collection API](https://next.dataweave.com/us/data-collection-api)
- Price API explicitly says it scrapes sources such as Amazon, eBay, and Google Shopping, and supports country/source specific jobs for product and offer data. Its current pricing page lists paid plans starting at €99 per month, but its help article says plans start at €499, an unresolved discrepancy. — [Price API overview](https://readme.priceapi.com/docs/an-overview-of-price-api); [Price API workflow](https://readme.priceapi.com/v1/docs/basic-workflow); [Price API pricing](https://www.priceapi.com/pricing); [Price API cost article](https://readme.priceapi.com/docs/costs-subscription-plans-and-contracts)
- PricesAPI is another search/offer service: it returns product candidates and merchant offers by text or retailer URL, with coverage varying by market and product. Its published Developer plan is $49/month for 30,000 credits, with a product-bearing search charged 10 credits. — [PricesAPI docs](https://pricesapi.io/docs); [PricesAPI pricing](https://pricesapi.io/pricing)

### Inferences
- These tools could enrich a product URL supplied by a user or a licensed feed, but using them as a workaround to collect restricted retailer catalogues would preserve the access and image-rights problem.
- Price intelligence products are better for checking known products than furnishing a curated, continuously complete fashion catalogue.

### Gaps
- The reviewed vendor pages do not establish Dressed's right to cache, redistribute, or display extracted retailer images and listings. Written vendor and retailer terms must answer this before a public integration.
- No public evidence confirms that these services cover Depop or Vinted listings reliably or have a complete PacSun/Hollister assortment.

## Which options should Dressed evaluate first?

### Takeaway
Run a small vendor evaluation of one approved multi merchant search API alongside an authorized retailer or affiliate feed. Measure actual fashion coverage and rights before adapting Dressed's backend.

### Cited Findings
- Firmly explicitly gates search results by the merchants associated with an account; its rate limits and production configuration are shared during commercial onboarding. — [Firmly Discovery](https://developers.firmly.ai/api-reference/discovery/); [Firmly API reference](https://developers.firmly.ai/api-reference/)
- Lykdat has a ready fashion image search catalogue but requires an API key, and its own documentation separates global search from searching a user-created catalogue. — [Lykdat API docs](https://apidocs.lykdat.com/)
- Diffbot's docs position Product Extract as appropriate when an exact page URL is known, rather than as a curated product feed. — [Diffbot Products Overview](https://www.diffbot.com/products/overview)

### Inferences
- Shortlist Firmly for a cross retailer discovery proof of concept and Lykdat for a later visual match proof of concept. Keep an affiliate feed as the more direct route for a durable Dressed catalogue with product provenance.

### Gaps
- Vendor account access and actual sample responses are needed to judge relevance, retailer coverage, age of listings, costs at projected traffic, and contractually allowed image display.
