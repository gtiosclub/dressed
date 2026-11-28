# Open and low-approval fashion data

## Is there a reusable real fashion catalogue without a partner application?

### Takeaway
One unusually concrete candidate is Livostyle's self-published women's fashion dataset, but its current refresh and downstream image rights need verification before a public Dressed launch. I found no comparable open, current, multi-retailer feed covering Depop, eBay, PacSun, and Hollister.

### Cited Findings
- The [Livostyle catalogue repository](https://github.com/arturayupov/womens-fashion-catalog-open-data) claims a JSON/Parquet feed of 2,770+ women's products, product URLs, prices, variants, and approximately 2,770 thumbnails. It claims weekly Shopify Admin API sync, and the [MIT dataset license](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/LICENSE) names Arcada LLC (d/b/a Livostyle) as copyright holder and permits copies of the dataset for commercial use subject to including the license notice. — [Repository](https://github.com/arturayupov/womens-fashion-catalog-open-data); [license](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/LICENSE)
- The retailer's own site identifies its operator as Arcada LLC, matching the repository license, but also says it curates products from partner brands and uses Trendsi for fulfillment. I did not find a retailer-site statement connecting the GitHub account `arturayupov` to Arcada, nor proof that supplier photos may be sublicensed under MIT. — [Livostyle site](https://livostyle.com/); [repository license](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/LICENSE)
- The dataset's [raw stats file](https://raw.githubusercontent.com/arturayupov/womens-fashion-catalog-open-data/main/data/stats.json) reports `last_synced: 2026-10-18T06:02:35Z` and 2,938 products. As of November 11 this is about 24 days old, contradicting the repository's asserted weekly update cadence. — [Stats file](https://raw.githubusercontent.com/arturayupov/womens-fashion-catalog-open-data/main/data/stats.json); [repository](https://github.com/arturayupov/womens-fashion-catalog-open-data)
- The 28.7 MB product JSON could not be viewed through the available web tool, and the illustrative README product URL was not retrievable there; I could not validate a sample of current links or thumbnails. — [Product JSON file](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/data/products.json); [README](https://github.com/arturayupov/womens-fashion-catalog-open-data)
- A [Hugging Face fashion dataset](https://huggingface.co/datasets/FindsAIDatabase/findsai-products) labels its rows MIT and contains products from Nordstrom, Neiman Marcus, and The RealReal, but product images and page URLs point to those retailers; the dataset page does not establish that those retailers licensed image republication. — [Dataset card](https://huggingface.co/datasets/FindsAIDatabase/findsai-products)

### Inferences
- Livostyle may serve as a bounded, real-product internal evaluation corpus and potentially a public source after independently checking publisher identity, sample link freshness, and especially image rights. Its narrow retailer coverage and stale latest sync make it unsuitable as evidence of a current broad catalogue by itself.
- An MIT label on a third-party scraper dataset does not establish rights to source retailer photos or current availability.

### Gaps
- Independent proof that the GitHub account can grant rights on behalf of Livostyle and its upstream product-image suppliers.
- Verified sample product URL/image success and a reason the purported weekly sync was not recent.

## Are public ecommerce endpoints or open knowledge graphs a shortcut?

### Takeaway
Public endpoint access is not equivalent to a reusable cross-retailer catalogue. Shopify's no-token product endpoint is expressly part of a merchant's hosted theme; Wikidata is open but not a current offer feed.

### Cited Findings
- Shopify says its unauthenticated [Ajax API](https://shopify.dev/docs/api/ajax) is for themes hosted by Shopify and cannot be used on a custom storefront; its [product endpoint](https://shopify.dev/docs/api/ajax/reference/product) returns JSON for a known product handle. Shopify Storefront API access uses per-shop access tokens created by an app with the relevant scopes. — [Ajax API](https://shopify.dev/docs/api/ajax); [product endpoint](https://shopify.dev/docs/api/ajax/reference/product); [Storefront token](https://shopify.dev/docs/api/admin-rest/latest/resources/storefrontaccesstoken)
- [Wikidata structured data is CC0](https://www.wikidata.org/wiki/Wikidata:Licensing), while media has separately determined licenses. Its knowledge graph is not presented as a source of live retailer price, stock, or purchase links. — [Wikidata licensing](https://www.wikidata.org/wiki/Wikidata:Licensing)
- [OpenProductData](https://openproductdata.org/api-dokumentation) documents a no-auth public API with 60 requests/minute and search by name, brand, or category; it is a digital-product-passport dataset, and its documented output does not establish a broad fashion assortment or retail offer/checkout URL. — [API documentation](https://openproductdata.org/api-dokumentation)
- [Harpd's open product directory](https://harpd.com/data/products/) is CC BY 4.0 with no API key, but its sample entry and schema describe software-style product entities rather than apparel offers with sizes, stock, prices, and retailer checkout links. — [Dataset documentation](https://harpd.com/data/products/)

### Inferences
- Parsing `products/{handle}.js` across arbitrary Shopify stores would create a crawler-like ingestion process, not an approved universal product API. Use Shopify Storefront API where the merchant cooperates.
- Wikidata can enrich brand/category metadata but cannot seed Dressed's current-shopping results.

### Gaps
- No official evidence found that PacSun, Hollister, Depop, or Vinted grant public third-party catalogue/image reuse through an uncredentialed endpoint.

## What is safe for a zero-cost club demonstration?

### Takeaway
For UI and ranking tests, synthetic data is immediate. For real products, reviewed user-shared links and a carefully checked single-source open feed are more realistic than trying to bulk import all trendy retailers.

### Cited Findings
- [DummyJSON](https://dummyjson.com/docs/products) explicitly describes its product data as sample information for testing/prototyping, including names, prices, images, categories, and a `womens-dresses` category; it is not a source of live retailer listings. — [Product docs](https://dummyjson.com/docs/products)
- Shopify's Storefront API tokens are per shop and created by an app with scopes, while its Ajax API is theme-oriented, so neither supplies automatic open access to all Shopify-hosted fashion stores. — [Storefront token](https://shopify.dev/docs/api/admin-rest/latest/resources/storefrontaccesstoken); [Ajax API](https://shopify.dev/docs/api/ajax)
- The Livostyle repository expressly provides a machine-readable JSON file and MIT terms for its dataset, but the raw freshness report is older than its advertised weekly schedule. — [Repository](https://github.com/arturayupov/womens-fashion-catalog-open-data); [license](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/LICENSE); [stats](https://raw.githubusercontent.com/arturayupov/womens-fashion-catalog-open-data/main/data/stats.json)

### Inferences
- A good no-approval evaluation stack is: current Dressed synthetic fixture for deterministic app tests, plus a separately labeled Livostyle sample for real-product parser and ranking experiments after link/image audit. User-supplied HTTPS links can populate a private Wishlist without claiming a general catalogue or verified current offer.
- Avoid carrying third-party image URLs, prices, or availability into a public persistent catalogue when the source has not licensed or recently verified them.

### Gaps
- DummyJSON's example images may depict real brands; its docs do not establish rights to redistribute every image in a published app.
- Livostyle's supplier image sublicensing and November product freshness remain unresolved.
