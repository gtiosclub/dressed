# Self-service shopping search APIs and aggregators

## Which services can a club try promptly, and at what price?

### Takeaway
SerpApi and SearchApi offer self-service trials with live shopping search results; DataForSEO has a small trial credit but requires a $50 minimum top-up for continued use. These are search-result extraction services, not pre-licensed retailer product feeds.

### Cited Findings
- SerpApi lists a $0 plan with 250 successful searches per month and 50 per hour; its next plan is $25/month for 1,000 searches. A vendor getting-started article says the free signup needs no credit card. — [SerpApi pricing](https://serpapi.com/pricing); [SerpApi getting started](https://www.serpapi.com/blog/introducing-serpapis-claude-code-plugin/)
- SerpApi's Google Shopping endpoint returns title, source, price, product link, and thumbnail fields from search results. — [SerpApi Google Shopping](https://serpapi.com/shopping-results)
- SearchApi advertises 100 free requests with no credit card for Google Shopping and a $40/month developer plan with 10,000 searches. It also documents a direct eBay search extraction endpoint with links, item IDs, prices, and thumbnails. — [SearchApi Shopping](https://www.searchapi.io/google-shopping); [pricing](https://www.searchapi.io/pricing); [eBay endpoint](https://www.searchapi.io/docs/ebay-search-api)
- DataForSEO offers a $1 trial credit and requires at least a $50 top-up afterward; funds do not expire. Its Google Shopping API charges per returned product/seller/SERP: $0.001 in the standard queue (up to 45 minutes), $0.002 in the priority queue (up to 1 minute). — [DataForSEO minimum payment](https://dataforseo.com/help-center/minimum-payment); [pricing](https://dataforseo.com/pricing/merchant/google-shopping-api)
- Firmly's Discovery API searches multiple merchant catalogs, but results are limited to domains authorized for the account; extra domains require contacting an account manager, and thresholds are shared during commercial onboarding. — [Firmly Discovery](https://developers.firmly.ai/api-reference/discovery/); [API reference](https://developers.firmly.ai/api-reference/)
- Lykdat describes searching its own fashion product catalog and asks users to create a business account for API keys; the documented regular image-search flow requires a catalog created under the user's account. No public price was verified in these sources. — [Lykdat API docs](https://apidocs.lykdat.com/)

### Inferences
- SerpApi is the least-friction way to test on-demand cross-retailer product search without an upfront payment. SearchApi is an alternative for direct eBay text search. DataForSEO is more attractive for higher-volume batch experiments than for an interactive club demo because of its queue and $50 deposit.
- None of these APIs proves Dressed has a stable, complete PacSun, Hollister, Depop, or Vinted catalog; exact retailer coverage should be measured with queries and link validation before promising it.

### Gaps
- No official source establishes that any of the four named retailers/platforms is consistently covered in shopping results, nor provides a guaranteed merchant inventory for these APIs.
- No public Firmly or Lykdat price/approval timeline was verified.

## Can the results be displayed and stored as a Dressed catalogue?

### Takeaway
Easy API access does not convey blanket rights to republish third-party listings or images. A temporary search-result experiment is materially different from persisting a catalogue and reusing product photos.

### Cited Findings
- SearchApi's terms say search data can include third-party text, images, and video, and that the user may use protected content only with an appropriate license or other legal permission. Its legal-protection guarantee excludes claims from the customer's use, storage, redistribution, or commercialization of data and applies only to paid Production plans and above. — [SearchApi terms](https://www.searchapi.io/legal/terms)
- DataForSEO says its standard terms grant no resale, sublicensing, or redistribution right for an untransformed standalone feed, database dump, public endpoint, or raw API service without separate written agreement. — [DataForSEO legal FAQ](https://dataforseo.com/help-center/quick-answers-to-frequently-asked-legal-questions)
- SerpApi's legal page prohibits illegal use including copyright and other intellectual-property infringement; its Google Shopping documentation describes data scraped from Google Shopping search results. Its public pages reviewed did not state that retailer images may be cached or republished in Dressed. — [SerpApi legal](https://serpapi.com/legal); [Google Shopping API](https://serpapi.com/shopping-results)
- Firmly says its discovery price and stock are from a scheduled catalog snapshot and can lag; it recommends confirming via the Catalog API before showing final price or adding to cart. — [Firmly Search Products](https://developers.firmly.ai/api-reference/discovery/search/)

### Inferences
- For a v0 experiment, proxy a bounded on-demand query, show source attribution and an outbound link, avoid presenting price or availability as guaranteed, and do not import search results into the permanent public catalog until display, image, caching, and retention rights have been resolved.

### Gaps
- SerpApi's public legal page reviewed does not settle the precise right to display third-party product images inside an iOS app; ask the vendor or consult applicable source terms before a public release.
- SearchApi's service terms do not grant a blanket retailer image license.

## Does an easy API support photo matching and Depop or eBay specifically?

### Takeaway
SearchApi exposes direct eBay text search and Google Lens visual search, while SerpApi exposes Google Lens and Shopping; these paths can prototype similar-item discovery, but they do not create an official Depop integration or prove exact product identity.

### Cited Findings
- SearchApi documents live eBay search results via `engine=ebay_search`, returning listing IDs, links, prices, and thumbnails. — [SearchApi eBay Search](https://www.searchapi.io/docs/ebay-search-api)
- SearchApi reports that Google's Lens Products tab was removed on October 7, 2026; its Lens API now directs users to visual matches, with a follow-up Shopping query for priced listings. — [SearchApi Google Lens](https://www.searchapi.io/docs/google-lens)
- SerpApi documents image upload for use with engines including Google Lens, and its Lens API returns visual matches. — [SerpApi Image API](https://serpapi.com/image-api); [Lens API](https://serpapi.com/google-lens-api)
- Firmly's discovery results are restricted to an account's authorized merchant domains, so its documentation cannot establish Depop or eBay coverage for Dressed. — [Firmly Discovery](https://developers.firmly.ai/api-reference/discovery/)

### Inferences
- SearchApi eBay text results are a quick technical demonstration when official eBay Browse production approval is unavailable, but the source is scraped pages rather than licensed eBay API data, so Dressed should not describe it as an official eBay integration.
- A Lens result is a visual resemblance candidate; it should be labeled similar unless a source URL or product identifier verifies identity.

### Gaps
- No vendor documentation reviewed verifies broad Depop inventory or authorizes Depop content reuse. Coverage tests may find individual indexed pages, which would not amount to a dependable catalogue.
