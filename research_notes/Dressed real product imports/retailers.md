# Pacsun and broad retailer acquisition

## What is the concrete Pacsun route?

### Takeaway
Pacsun's own current footer directs affiliate applicants to Impact. Apply through that route and ask specifically for its product catalog and native-app display rights; public evidence of an affiliate program is not evidence that Dressed can already download its feed.

### Cited Findings
- Pacsun's official site-map footer contains “Affiliate Program” linking to `https://app.impact.com/campaign-promo-signup/PacSun.brand`. The target redirected in a loop during this research, so no application or account was inspected. This is stronger current evidence than third-party directories listing CJ. — [Pacsun official site map](https://www.pacsun.com/content/site-map.html)
- Impact allows partners to download product catalogs in the portal, through FTP, or through API. Partners must have joined a brand that has uploaded a catalog; API access must be enabled. — [Impact partner catalog downloads](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)
- Brands can restrict catalog access to specific partners and select permitted download methods (FTP, API, portal). — [Impact brand catalog configuration](https://help.impact.com/brand/what-would-you-like-to-learn-about/platform-features/product-catalogs/add-product-catalogs-as-a-brand)
- Impact offers standardized CSV, TAB, and XML feed formats. — [Impact feed preferences](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/set-product-catalog-feed-preferences-as-a-partner)

### Inferences
- For Pacsun, the useful next business action is an Impact application with a Dressed demo and a specific request: product IDs, titles, images, variant/size data, price, stock, product URLs, refresh cadence, native iOS display, storage and image-derived retrieval permissions. This is a recommendation, not a claim these rights are offered.
- A manually downloaded approved catalog can establish the first real import before automating API access. The feed transport is secondary to actually obtaining accessible, usable product data.

### Gaps
- No Pacsun public catalog API was verified. No authenticated Pacsun Impact feed, product counts, coverage, feed price, acceptance criteria, or Dressed approval was inspected.
- Do not promise that joining Impact alone grants Pacsun catalog access or that affiliate linking rights allow indefinite image storage or embeddings.

## Which broad catalog options are realistic?

### Takeaway
Awin offers a documented feed-discovery path; Skimlinks has useful catalog products but its current Product Key access is Managed-tier only. These are candidates to qualify, not guaranteed “everything” APIs.

### Cited Findings
- Awin's feed list includes joined advertisers plus advertisers allowing promotion before joining. It supplies product counts, update times, and feed URLs and requires Publisher ID plus a separate data-feed key. — [Awin feed-list documentation](https://help.awin.com/developers/docs/downloading-a-list-of-your-product-feeds)
- Awin says missing columns reflect information the advertiser did not supply. A feed can exist but require contacting the advertiser if unavailable. — [Awin product feed FAQ](https://success.awin.com/articles/en_US/Knowledge/Product-Data-Feed-FAQ)
- Skimlinks explicitly separates an on-demand Product Key API (URL, product identifier, keyword lookup) from bulk merchant/category Publisher Export files for building a local catalog. Both draw from the same data; ordinary refresh is roughly daily and merchant cadence varies. — [Skimlinks API versus feed](https://support.skimlinks.com/hc/en-us/articles/39795251710621-Product-Key-API-vs-Data-Feed-Which-Should-I-Use)
- Skimlinks Product Keys are only available to Managed accounts; its support team cannot issue them to Growth accounts. Standard link-generation access does not establish programmatic product API access. — [Skimlinks Product Key eligibility](https://support.skimlinks.com/hc/en-us/articles/26619916595869-What-is-a-Product-Key-and-do-I-need-one)
- Sovrn requires all sites/apps/toolbars to receive Network Quality approval for affiliation. Its current API index lists Product Recommendation and Price Comparisons. — [Sovrn approval and API implementation](https://knowledge.sovrn.com/kb/api-implementation-with-commerce), [Sovrn API index](https://developer.sovrn.com/)

### Inferences
- Prioritize one approved Pacsun feed and one broader network feed rather than implementing several speculative connectors. Ask providers to return actual example results for Pacsun/target brands before investing in integration.
- For a small student app, merchant cooperation or accepted affiliate feed access is more dependable than assuming aggregator membership includes unrestricted product exports.

### Gaps
- Pacsun coverage was not verified within Awin, Skimlinks, or Sovrn product feeds. No claim that any of them includes Depop or every eBay listing is supported.
- Public sources did not establish Dressed-specific eligibility, pricing, minimum traffic, bulk export approval, or image caching/embedding rights.

## Can Shopify supply participating small shops?

### Takeaway
Yes: a cooperating Shopify merchant is a useful controllable pilot. Shopify's Storefront API supports native apps and product access, but is a per-shop commerce surface rather than one verified catalog of every Shopify merchant.

### Cited Findings
- Shopify documents product/collection display and native-app use. Storefront API supports tokenless products, collections, and search with a 1,000 complexity limit; tags/metafields and other advanced features require token access. The Headless channel manages storefront tokens, permissions and product publishing. Private tokens belong server-side. — [Shopify Storefront documentation](https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api)

### Inferences
- Invite a few local boutiques or resale sellers to opt into catalog display, using a merchant-provided CSV first or a Shopify connector where appropriate. This yields real, attributable products without waiting for broad-retailer agreements.
- Tokenless technical access is not itself a blanket grant to copy all shops' images into a public Dressed catalog. Agree on display, refresh and retention for the cooperating shop.

### Gaps
- No participating merchant was identified or contacted. Shopify functionality does not establish Pacsun's ecommerce platform or supply Pacsun access.
