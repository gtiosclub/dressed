# Affiliate networks as broad fashion catalogues

## Which platforms provide multi-retailer product data?

### Takeaway
Impact.com, Awin, Rakuten Advertising and CJ offer multi-advertiser product feeds or APIs. They are a practical route to structured fashion products, but each advertiser decides whether it supplies a feed and grants a publisher access.

### Cited Findings
- impact.com lets partners download joined brands' catalogues through the platform, FTP or API; its standardized format makes different brands' fields consistent. The brand controls whether it uploads a catalogue, and API access must be enabled. — [impact.com partner catalogue guide](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)
- Awin provides feeds from advertiser partners and a Publisher Product API for enhanced Google-format feeds; the API does not support legacy feeds. Advertisers choose which fields appear. — [Awin product feed FAQ](https://success.awin.com/articles/en_US/Knowledge/Product-Data-Feed-FAQ)
- Awin feeds commonly contain title, price, images, deep links and sometimes fashion attributes such as size and colour. — [Awin product feed overview](https://success.awin.com/articles/en_US/Knowledge/What-is-a-Product-Data-Feed)
- Rakuten requires both technical approval and approval from each participating advertiser, then offers full, delta and category feed files through SFTP. It also documents a Product Search API against advertiser partners. — [Rakuten implementation guidelines](https://pubhelp.rakutenadvertising.com/hc/en-us/articles/11258487715981-Product-Catalog-Data-Feed-Implementation-Guidelines); [Rakuten product links](https://pubhelp.rakutenadvertising.com/hc/en-us/articles/10623933503373-Product-Links)
- CJ advertises a publisher Product Feed GraphQL API searchable by criteria such as price, currency, country and UPC. Its public developer portal does not establish which fashion advertisers a new publisher can access. — [CJ developer portal](https://developers.cj.com/)

### Inferences
- Dressed should model each retailer as a distinct approved source even when one network delivers multiple feeds. A network integration reduces transport work, but it does not create a universal fashion catalogue.
- Awin's enhanced Google format and impact.com's standardized format look like the easiest first parsers for Dressed's existing feed schema; actual brand access decides which is useful first.

### Gaps
- Public documentation does not verify which of PacSun or Hollister currently exposes a product feed to a new Dressed publisher account. That requires account-specific approval and inspection.
- Public documentation reviewed does not provide a comparable publisher price schedule for these catalogue feeds.

## How fresh are the feeds and what content may Dressed display?

### Takeaway
Freshness depends on the retailer's updates plus the network's processing. Feed access is not blanket permission to cache images indefinitely or use content in every app surface; the signed advertiser terms must be checked.

### Cited Findings
- impact.com advises brands to update catalogues daily with current price and stock; its catalogue display synchronizes API changes once per day. — [impact.com partner catalogue guide](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)
- Awin says advertisers often update feeds multiple times daily and exposes a Last Update value to check the copy being used. — [Awin product feed FAQ](https://success.awin.com/articles/en_US/Knowledge/Product-Data-Feed-FAQ)
- Rakuten offers delta files for new, changed and deleted records and describes daily update use for large publisher catalogues. — [Rakuten implementation guidelines](https://pubhelp.rakutenadvertising.com/hc/en-us/articles/11258487715981-Product-Catalog-Data-Feed-Implementation-Guidelines); [Rakuten overview](https://pubhelp.rakutenadvertising.com/hc/en-us/articles/4412243602189-Product-Catalog-Overview)
- Awin says accepted publishers may use advertiser images supplied in its platform/datafeed, but recommends consent for images taken separately from the advertiser's website. — [Awin image-use FAQ](https://success.awin.com/s/article/Can-I-use-any-images-from-the-advertiser-s-website?language=en_US)

### Inferences
- Dressed should store source update timestamps, set a source-specific freshness window, recheck outgoing links, and omit or label old prices and stock. Daily feed updates do not guarantee instant availability for fast-changing fashion products.
- Dressed should ask each program whether its iOS Discovery screen, image caching, and similarity indexing are approved uses. A permission to use feed images for promotion does not automatically answer those questions.

### Gaps
- The reviewed general platform help pages do not specify Dressed's allowed image retention, app-surface rights, or rights to build image embeddings; those are likely agreement-specific.
- Feed-specific product counts and update lag for PacSun/Hollister cannot be verified without partner access.

## What is the best next step for Dressed?

### Takeaway
Investigate impact.com and Awin partner access, then pilot one approved brand feed. The main work is source approval and policy review, followed by a small deterministic adapter to the existing importer.

### Cited Findings
- impact.com requires joining a brand that uploaded a catalogue before its feed is visible. — [impact.com partner catalogue guide](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)
- Rakuten requires approval at both platform and advertiser levels before an automated feed is available. — [Rakuten implementation guidelines](https://pubhelp.rakutenadvertising.com/hc/en-us/articles/11258487715981-Product-Catalog-Data-Feed-Implementation-Guidelines)
- Awin's advertiser dashboard shows whether a current partner offers a feed; missing feeds can be requested from the advertiser or account manager. — [Awin product feed FAQ](https://success.awin.com/articles/en_US/Knowledge/Product-Data-Feed-FAQ)

### Inferences
- Compare candidate partners on approved retailer count, category depth, source update timestamp, unique IDs, deep links, image terms and mobile-app permission before choosing a platform. Feed capability alone should not be the selection criterion.
- Depop and Vinted should not be presumed present in retail affiliate feeds: these platforms are marketplaces, and this research found no official affiliate-network catalogue claim for them.

### Gaps
- PacSun and Hollister feed membership, access terms and product coverage remain unverified until Dressed has approved publisher accounts or direct agreements.
