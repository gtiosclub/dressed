# PacSun and Hollister catalogue access

## Is there an approved feed or API route for PacSun and Hollister?

### Takeaway
PacSun is the clearer first outreach candidate: its own site links an affiliate application on impact.com, whose platform supports partner product feeds and API retrieval. This does **not** establish that PacSun supplies Dressed a feed or grants image display rights; acceptance and feed access must be checked in the partner account. Hollister's official program is a creator affiliate program, with no verified general product feed route found.

### Cited Findings
- PacSun's website links its “Affiliate Program” directly to an impact.com PacSun campaign application. — [PacSun site footer](https://www.pacsun.com/pacsun/)
- impact.com states that partner catalogues can be downloaded through its platform, FTP, or API, and describes a brand's feed as product metadata. — [impact.com partner catalogue guide](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)
- impact.com says brands must enable catalogue visibility, and may restrict access to selected partners. — [impact.com brand catalogue guide](https://help.impact.com/brand/what-would-you-like-to-learn-about/platform-features/product-catalogs/add-product-catalogs-as-a-brand)
- Hollister advertises a Style Hub creator partnership with commissions and an application; eligibility includes over 1,500 TikTok or Instagram followers. — [Hollister Community](https://www.hollisterco.com/shop/us/br/Community?pagefm=navigation-footer)
- Hollister's Style Hub FAQ describes personal storefronts and affiliate links for participating creators. — [Hollister Style Hub FAQ](https://community.hollisterco.com/account/faq)

### Inferences
- Apply to PacSun's affiliate program (or seek direct brand permission), then inspect the actual partner contract, available catalogue, permitted surfaces, image use, and update interval before writing a live connector. impact.com's technical capability is not PacSun-specific authorization.
- The Hollister creator program may be unsuitable for a product search app; direct partnership outreach is more appropriate than assuming its creator links are a catalogue licence.

### Gaps
- No official public PacSun or Hollister product catalogue API documentation or PacSun-specific feed availability was verified.
- No permission or partner contract for Dressed was supplied, so catalogue caching, image display, and refresh rights remain unconfirmed.

## Can Dressed crawl their public product pages instead?

### Takeaway
PacSun's current terms expressly bar systematic collection and automated access, including robots/spiders. Hollister's accessible official terms restrict copying, commercial use, and linking, though the accessible page may be legacy; Dressed should obtain current terms or written permission before considering crawling.

### Cited Findings
- PacSun grants only limited personal, noncommercial use and expressly excludes systematic collection of content/data, including spiders and robots, as well as third-party publication/display. — [PacSun Terms of Use, updated March 2025](https://www.pacsun.com/company/terms-of-use.html)
- PacSun further prohibits automated devices or processes to access its services for any purpose, including monitoring or copying material. — [PacSun Terms of Use](https://www.pacsun.com/company/terms-of-use.html)
- PacSun's robots file disallows several search, variation, and filter endpoints and points to sitemaps; this is a crawl directive, not a reuse licence. — [PacSun robots.txt](https://www.pacsun.com/robots.txt)
- An accessible Hollister terms page limits website content to personal purchasing use and bars copying, publication/display, commercial use, inline linking and even linking to Hollister pages without authorization. Its date/current applicability is unclear because the site's newer “Website Terms of Use” link was not retrievable. — [Hollister site use page](https://www.hollisterco.com/hol/site_use.html); [current site footer linking terms](https://www.hollisterco.com/shop/us/br/Community?pagefm=navigation-footer)
- Hollister's robots file disallows search, product and category controller paths; this is separate from rights to reuse catalogue content. — [Hollister robots.txt](https://www.hollisterco.com/robots.txt)
- PacSun warns that descriptions, prices and availability can be inaccurate or change, and Hollister likewise says product information can change without notice. — [PacSun Terms of Use](https://www.pacsun.com/company/terms-of-use.html); [Hollister site use page](https://www.hollisterco.com/hol/site_use.html)
- impact.com advises brands to update catalogues daily with price and stock data; its catalogue detail exposes a last-updated time. — [impact.com partner catalogue guide](https://help.impact.com/partner/what-would-you-like-to-learn-about/platform-features/marketing-content/product-marketplace-and-catalogs/download-product-catalogs-as-a-partner)

### Inferences
- An “agentic crawler” would still be automated collection. AI parsing does not change the source's terms or grant image rights. Prioritize a signed feed/API relationship; only crawl a narrowly approved source with explicit permitted paths, rate, retention and image display terms.
- Even with a partner feed, Dressed should show last-checked time, validate outgoing links, and avoid promising live inventory unless the source provides an appropriate freshness guarantee.

### Gaps
- The newest Hollister terms linked from its site could not be fetched; the accessible terms page may be outdated. Confirm directly with Hollister before relying on it for implementation decisions.
- No source-specific PacSun partner feed update cadence or image rights were independently verified.
