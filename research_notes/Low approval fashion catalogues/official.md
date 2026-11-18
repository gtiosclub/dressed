# Official retail and marketplace APIs with low approval friction

## Which APIs can provide live, real product listings without a lengthy partner review?

### Takeaway
Among the official APIs checked, Best Buy presents the clearest self-service developer-key path, but is a poor fashion source. Shopify's tokenless Storefront API can query products from an individual Shopify shop, but does not provide a cross-retailer catalogue. The fashion-relevant marketplace APIs checked involve review or eligibility hurdles.

### Cited Findings
- Best Buy's developer portal advertises a “Get API Key” path and a Products API with price, availability, descriptions, and images for its own catalogue; registration is required under its terms. — [Best Buy developer portal](https://developer.bestbuy.com/); [Products API](https://developer.bestbuy.com/apis); [terms](https://developer.bestbuy.com/legal)
- Best Buy's terms allow its API content in developer applications connected with offers to sell its products, require its logo where the API appears, and restrict caching content to at most 72 hours. Published limits are 50,000 calls/day and 5 calls/second for Products and related APIs. — [Best Buy terms and operational policy](https://developer.bestbuy.com/legal)
- Shopify's Storefront API supports tokenless queries for products, collections, and search and is intended for customer experiences with a particular shop. Public and private Storefront access tokens, where used, are created or obtained per shop. — [Shopify Storefront API](https://shopify.dev/docs/api/storefront/latest); [Shopify authentication](https://shopify.dev/docs/api/usage/authentication)
- Walmart offers an affiliate marketing API with product information that can be used in apps, but its published terms say the API is available to affiliate partners for advertising Walmart products; feed access is restricted and requested by category. — [Walmart API overview](https://www.walmart.io/); [Walmart API terms](https://walmart.io/termsandcondition)

### Inferences
- Best Buy could validate Dressed's API integration mechanics, but it will not validate trendy apparel relevance.
- A participating Shopify merchant could be a low-friction first fashion shop if the merchant grants Dressed permission to feature its products; tokenless technical access alone does not establish permission to republish a shop-wide catalogue.

### Gaps
- Best Buy does not publish an API-key approval turnaround on the pages reviewed, nor a clear promise of zero fees; do not call it instant or free without signup verification.
- Shopify's tokenless access documentation does not establish authorization to aggregate unrelated merchants' listings in a separate Dressed catalogue.
- Walmart's current affiliate enrollment turnaround and Dressed-specific eligibility were not verified.

## Which marketplace APIs appear quick, and what blocks a live club v0?

### Takeaway
eBay sandbox access is quick but contains fictional listings. Etsy's cross-shop Personal App requires review, while Amazon's Creators API requires recent affiliate sales. None provides immediate, approval-free access to a live broad fashion catalogue.

### Cited Findings
- Anyone with an eBay developer account can use Buy APIs in sandbox, but production Buy API access is for approved partners and involves EPN application, review, and contracts. eBay itself advises completing production approval before substantial development. — [eBay Buy requirements](https://developer.ebay.com/api-docs/buy/buy-requirements.html)
- eBay's sandbox explicitly does not contain real eBay users or real listings. — [eBay sandbox and production](https://developer.ebay.com/api-docs/static/gs_understand-the-sandbox-and.html)
- eBay Browse supports keyword and image-based item search once authorized. — [Browse API](https://developer.ebay.com/develop/api/buy/browse_api)
- Etsy's Seller App can be approved within minutes only for a seller's own shop; a Personal App for use beyond one's own shop undergoes deeper review. Etsy's Commercial Access adds another manual review for broader use. — [Etsy Open API access levels](https://developers.etsy.com/documentation/)
- Etsy sets per-app daily and per-second limits visible in its developer portal; its API terms prohibit displaying listing content more than six hours older than Etsy's current listing. — [Etsy rate limits](https://developers.etsy.com/documentation/essentials/rate-limits/); [Etsy API terms](https://www.etsy.com/legal/api/)
- Amazon's Creators API exposes product search but requires Associates enrollment plus at least ten qualifying sales in the previous 30 days. Amazon does not permit caching image content, and permits caching image URLs and other product advertising content for up to 24 hours. — [Amazon Creators API](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/introduction); [Amazon programme policies](https://affiliate-program.amazon.com/help/operating/policies)

### Inferences
- An eBay sandbox integration is useful to prove the UI/API contract, but cannot demonstrate live fashion results. Etsy is a potential later marketplace source if its review succeeds; Amazon is unrealistic for a new club account without sales.

### Gaps
- Etsy's application review duration and fee, if any, are not specified in the official pages reviewed.
- eBay's approval is not guaranteed, and a fixed turnaround for all production access steps is not published in the cited requirements.

## What should Dressed do with these findings?

### Takeaway
If the user requires live, real fashion products immediately and cannot wait for partnership review, these official sources are poor fits except a consenting individual merchant's shop. Treat search-result services or user-shared product links as a separate v0 path, with their own data-use checks.

### Cited Findings
- Shopify's Storefront API exposes product and search queries without a token for shop storefront experiences. — [Shopify Storefront API](https://shopify.dev/docs/api/storefront/latest)
- Best Buy's license limits use to its products and sets explicit branding and caching rules; Etsy's listings must be refreshed within six hours; Amazon's content has much shorter retention conditions. A persistent multi-source catalogue cannot simply store all these API responses forever. — [Best Buy terms](https://developer.bestbuy.com/legal); [Etsy API terms](https://www.etsy.com/legal/api/); [Amazon programme policies](https://affiliate-program.amazon.com/help/operating/policies)

### Inferences
- For an official-source pilot, seek one small Shopify fashion shop willing to participate, or use Best Buy only as a technical test. For fast cross-retailer results, evaluate third-party search APIs separately rather than equating technical search access with catalogue reuse rights.

### Gaps
- No official broad, current, approval-free fashion marketplace API covering Depop, Vinted, PacSun, and Hollister was established by this search.
