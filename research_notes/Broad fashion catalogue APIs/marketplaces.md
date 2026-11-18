# Broad marketplace product APIs

## Which official marketplace APIs offer broad fashion search?

### Takeaway
eBay Browse and Etsy Open API expose cross-seller item search. Amazon Creators API exposes a broad Amazon product search but has a sales threshold and tight content rules. None is a cross-retailer database of PacSun, Hollister, Depop and Vinted listings.

### Cited Findings
- eBay Browse searches listings by keyword, category, product identifier or image and retrieves item details; it requires an application access token. [eBay Browse API](https://developer.ebay.com/develop/api/buy/browse_api)
- eBay says production Buy API access is intended for approved partners, requires an application through the eBay Partner Network, and is not guaranteed; its sandbox is more generally available. It advises applying before significant implementation work. [eBay Buy API requirements](https://developer.ebay.com/api-docs/buy/buy-requirements.html)
- eBay's published default Browse limit is 5,000 calls per day for methods other than `getItems`; the Feed API is separate and feed file access requires eBay Partner Network membership. [eBay API limits](https://developer.ebay.com/develop/api/buy/api_call_limits), [eBay Buy API requirements](https://developer.ebay.com/api-docs/buy/buy-requirements.html)
- Etsy Open API's `findAllListingsActive` returns active listings across Etsy, with keyword search and pagination (maximum page size 100). The endpoint is API-key authenticated. [Etsy API reference](https://developers.etsy.com/documentation/reference)
- Etsy describes Personal App approval for limited use beyond one's own shop, and reviewed Commercial Access for broader approved applications. [Etsy developer access levels](https://developers.etsy.com/)
- Amazon Creators API has `SearchItems`, `GetItems` and variation lookup; `SearchItems` returns at most 10 products per request. [Amazon Creators introduction](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/introduction), [SearchItems](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/search-items)
- Amazon's published prerequisite is enrollment in Associates for the target marketplace and at least 10 qualifying sales in the preceding 30 days for API access, plus registration and credentials. [Amazon Creators introduction](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/introduction)
- Amazon says PA API users should migrate to Creators API, which uses OAuth bearer tokens. [Amazon migration guide](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/migrating-to-creatorsapi-from-paapi)

### Inferences
- eBay or Etsy can provide a *single marketplace's* diverse secondhand or independent-seller selection, but their approval paths make them uncertain as the first production source. Amazon is broad but less aligned with Dressed's named youth-fashion retailers and its content rules make a stored local catalogue less straightforward.

### Gaps
- Approval of Dressed's particular shopping/discovery use case by eBay or Etsy is unknown.
- Official docs do not establish that the named PacSun, Hollister, Depop and Vinted inventories are comprehensively available through any one of these APIs.

## What freshness, licensing and operational constraints matter?

### Takeaway
These APIs are not unrestricted data dumps. Approval, rate limits, display terms, refresh obligations and image handling govern whether Dressed may persist and show a local projection.

### Cited Findings
- Etsy applies per-application queries-per-second and rolling queries-per-day limits, disclosed in each app's portal and response headers; a `429` includes `retry-after`. [Etsy rate limits](https://developers.etsy.com/documentation/essentials/rate-limits/)
- Etsy's current API terms say listing content shown by an app must be no more than six hours older than Etsy's corresponding content; other Etsy content has a 24-hour display freshness limit. Caching must last no longer than reasonably necessary. [Etsy API terms](https://www.etsy.com/ca/legal/api)
- Amazon's Associates policies prohibit storing or caching product advertising images themselves; image links can be stored for up to 24 hours, and other product advertising content generally up to 24 hours before refresh. Pricing or availability displayed from feeds or refreshed less often than hourly requires a timestamp. [Amazon Associates policies](https://affiliate-program.amazon.com/help/operating/policies)
- Amazon Creators best-practice documentation gives shorter suggested cache TTL for offer content (one hour) and up to a day for other item fields, subject to its license. [Amazon Creators caching guide](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/concepts/best-programming-practices)
- eBay says its APIs are intended to grow buying or selling on eBay and it typically does not permit other uses of eBay data. [eBay developer support](https://developer.ebay.com/support/developer-account-support)

### Inferences
- Dressed's current SQLite importer can normalize approved results, but its storage/refresh behavior must be adapted per provider rather than treating every provider as a permanent catalogue feed. Etsy's six-hour display rule is particularly consequential for scheduled ingestion.
- Backend-held credentials and a public DTO remain appropriate for each provider; the app should open the source listing and avoid claims of exact identity based on visual similarity alone.

### Gaps
- Exact eBay listing/image retention conditions for the proposed Dressed experience require review of the current approved agreement, not just the public API summary.
- Etsy's particular image display terms and Dressed's commercial approval status are not known.

## Can Depop or Vinted supply the requested broad marketplace catalogue?

### Takeaway
No official cross-seller catalogue feed for either was verified. Depop's documented partner API is seller-oriented; Vinted's US terms prohibit unauthorized automated extraction.

### Cited Findings
- Depop's Selling API describes enterprise partners automating listings and controls product reads through `products_read`; this documents seller integration rather than a public cross-seller search endpoint. [Depop Selling API](https://partnerapi.depop.com/api-docs/reference/)
- Vinted's US terms prohibit bots, scraping and crawling unless authorized or offered by Vinted, and separately prohibit data mining and screen scraping. [Vinted US terms](https://www.vinted.com/terms-and-conditions)

### Inferences
- For Depop, seller opt-in or direct platform partnership is more plausible than harvesting a general public catalogue. For Vinted, a direct permission discussion is needed before automated ingestion.

### Gaps
- Private partner arrangements may exist for either platform, but no public cross-seller feed/access terms were verified.
