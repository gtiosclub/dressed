# Local retailer catalog prototype

For the accepted hybrid approach and implementation sequence, see
[retailer import implementation](../../docs/retailer-import-implementation.md).

This prototype ingests a reviewed JSON feed into local SQLite and serves a read-only HTTP catalog on `127.0.0.1`. It makes no retailer requests, uses no cloud credentials, and does not deploy or sync to Firebase. The bundled source is synthetic: `.example` links are intentionally unusable.

From the repository root:

```sh
python3 backend/catalog/catalog.py --db /private/tmp/dressed-catalog.sqlite ingest backend/catalog/fixtures/demo-feed.json
python3 backend/catalog/catalog.py --db /private/tmp/dressed-catalog.sqlite search --query shirt
python3 backend/catalog/catalog.py --db /private/tmp/dressed-catalog.sqlite serve --port 8766
```

With the server running, `GET http://127.0.0.1:8766/products?q=shirt&category=tops` returns active results; `GET /products/{id}` returns one result, including its status. The server binds to loopback and exposes no write route. `Ctrl-C` stops it.

The feed supplies `source.id`, `source.name`, `source.allowedHosts`, `complete`, and `products`. A product needs `externalId`, `title`, `productURL`, and a Dressed category (defaults to `other`). Optional price uses integer cents plus a three-letter currency. The entire feed is validated before product changes. URL hosts must be listed in the feed. A failed feed records a failed run and leaves products unchanged. Repeating a successful feed keeps stable product IDs; a partial feed does not age out missing products. Two complete scans missing a product mark it unavailable.

Discovery → Search now requests `GET /products` over HTTP. For a simulator development check, start this server and launch the Debug app with `-catalogAPIURL http://127.0.0.1:8766`. A release build should set the Xcode build setting `CATALOG_API_BASE_URL` to the deployed HTTPS catalog service URL; without it, the app shows an unavailable state instead of sample products. The `export-demo` command remains useful for generating an offline API example, but its output is not bundled in the app:

```sh
python3 backend/catalog/catalog.py --db /private/tmp/dressed-catalog.sqlite export-demo /private/tmp/dressed-catalog-example.json
```

Run the behavior tests with `python3 -m unittest discover -s backend/catalog -p 'test_*.py' -v`. The HTTP test needs permission to bind a local port in sandboxed environments.

## Real open-data catalogue: Livostyle

Livostyle publishes its own product dataset under an [MIT license](https://github.com/arturayupov/womens-fashion-catalog-open-data/blob/main/LICENSE). The `livostyle.py` adapter converts a downloaded `data/products.json` snapshot to the existing catalog schema. It fixes the retailer and image hosts in code, preserves stable source IDs, maps categories, and only records a price when all variants share that exact price. It performs no retailer crawl or API signup.

```sh
curl -L --fail https://raw.githubusercontent.com/arturayupov/womens-fashion-catalog-open-data/main/data/products.json \
  -o /private/tmp/dressed-livostyle-products.json
python3 backend/catalog/livostyle.py /private/tmp/dressed-livostyle-products.json \
  --db /private/tmp/dressed-livostyle-catalog.sqlite
python3 backend/catalog/catalog.py --db /private/tmp/dressed-livostyle-catalog.sqlite \
  search --query dress
```

The dataset's copyright and permission notice must accompany any distributed copy or substantial extract. Remote Shopify image URLs are omitted by default; `--include-images` is an explicit local evaluation option after reviewing image-use rights. The dataset is a snapshot, so check its update date and sample product destinations before public use. This local import does not deploy the API or change the iOS app's configured catalog URL.

Before adding a live retailer connector, move approved source configuration out of the untrusted feed, confirm access and image-use terms, cap refresh frequency, and provide an authenticated backend deployment. Do not expose the local development server publicly.

## Saved eBay Browse response adapter

`ebay_browse.py` converts a **saved** eBay US Browse `item_summary/search` JSON response into this catalog's partial feed. It fixes the eBay product and image host allowlists in code, validates item IDs, prices, and URLs, and keeps a stable ID based on eBay's `itemId`. The Dressed category is an explicit operator choice; the source category remains separate. A keyword result is always a partial scan, so absent listings are not marked stale. This is a response adapter, not a live retailer connection or an exact product matcher.

Try it with synthetic data, without making an API request:

```sh
python3 backend/catalog/ebay_browse.py backend/catalog/fixtures/ebay-browse-response.json --category shoes --db /private/tmp/dressed-ebay-demo.sqlite
python3 backend/catalog/catalog.py --db /private/tmp/dressed-ebay-demo.sqlite search --category shoes
```

The fixture's eBay-shaped links are not real listings. Production use requires eBay Buy API access and a reviewed right to store and display its content. eBay's published daily API call limit is a rate limit, not a dollar cap. The adapter has no token handling, network request, schedule, or paid call path; live access stays off until credentials, terms, retention, and spending controls are resolved. Never put an application token or client secret in the iOS app or repository.

## Hybrid import experiment

`shopping_experiment.py` is a separate evaluation CLI, not a deployed API or public
catalog writer. It can call SerpApi using a backend environment key or replay saved
responses without network access. It evaluates up to 20 US/English queries and
the first ten results per query. Optional immersive-product calls resolve merchant
offers. No automatic retries, pagination, retailer requests, image downloads,
public publication or Wishlist writes occur. Every run persists locally by default.
Live runs additionally resolve up to three captured Google `/goto` links using
HTTP redirects only; destinations are never fetched. Set `--max-redirects 0` to
disable this. These requests do not use the SerpApi key or quota and have a separate
counter, `redirectRequestAttempts`. Results keep `destinationVerified: false`
because a redirect alone does not verify the product, variant, price or stock.

Resolve pending offers in an already saved live report without another SerpApi call:

```sh
python3 backend/catalog/merchant_redirects.py /path/to/saved/report.json --max-redirects 3
```

Each discovery candidate now includes the shared `retailProduct` object. See
[the retail-product contract](../schemas/README.md#retail-product-discovery-contract).
Supplied HTML supports galleries, descriptions, SKU/GTIN identifiers, material,
color/size attributes, explicit ProductGroup variants and separate offer ranges.
Multiple ambiguous products remain manual; matching a source URL can select its
Product node over unrelated recommendations. Google detail responses retain
gallery thumbnails, brand and variant-option groups without selecting a variant.

### Persistent discovery storage

All search runs save under `backend/catalog/local-data/` (ignored by Git):

- `discovery.sqlite`: live candidates keyed by provider and stable ID, plus append-only
  per-run observations. Unresolved candidates remain `needs_merchant_url`; resolved
  ones remain `needs_verification`. No candidate is automatically public or owned.
- `runs/<unique-run-id>/report.json`: normalized results and run status.
- `runs/<unique-run-id>/responses.json`: sanitized responses saved after each request,
  in the same shape accepted by `--fixture` for offline replay. Keys and credential
  query parameters are redacted. Failed request types are retained without raw
  exception messages. These archives do not download product images.
- `fixture-discovery.sqlite`: separate synthetic/replay data, never mixed into live data.

Use `--data-dir` to choose a different local root. `--output` is now optional and
writes an additional report copy; it does not disable the permanent archive. Earlier
runs are never overwritten. Completed queries are checkpointed before moving on;
an interrupted run retains its responses and completed observations. Local storage
is not cloud backup. Source-specific retention/removal policies still apply.

Uploaded/shared link acquisition and agents should eventually feed this discovery
stage through explicit source adapters, retaining original URLs and field evidence.
The source-approved fetcher and scheduled agent runner are not implemented yet.

Replay the synthetic search and offer fixtures:

```sh
python3 backend/catalog/shopping_experiment.py \
  --fixture backend/catalog/fixtures/shopping-replay.json \
  --queries backend/catalog/fixtures/shopping-replay-queries.json \
  --details-per-query 1 --output /private/tmp/dressed-shopping-replay.json
```

For a live trial, configure `SERPAPI_API_KEY` in the process environment using
your local secret manager. Do not place it in the repository, app, command-line
arguments or evaluation output. This command makes up to **40 potentially billed
request attempts**, including failed calls; the cap is shared across queries and
detail requests. Start with a one-query JSON file and `--max-requests 2` when
checking a new account.

```sh
python3 backend/catalog/shopping_experiment.py --live \
  --queries backend/catalog/fixtures/shopping-queries.json \
  --max-requests 40 --details-per-query 1 \
  --output /private/tmp/dressed-shopping-live.json
```

The default cap is one request and the default detail count is zero. Counts reset
each invocation; this is not an account-wide spending cap. A new process can make
new calls. A missing key fails before any request. HTTP errors are reduced to safe
codes; response archives redact API keys and credential query parameters.
Provider redirects are rejected. Detail failures stay on the candidate;
query failures are recorded and make the command exit nonzero after writing the
report. An empty successful search is distinct from a missing response field.

Reports include latency, request attempts, candidate/offer counts and unverified
merchant destinations. Presence of a URL, price or image is **not correctness**.
Human reviewers must check top-five relevance, destination, price, variant,
availability and image-use rights. Multiple stores retain their own prices; no
currency, stock or exact-match claims are inferred. Results never enter the
public SQLite catalog automatically. Candidates do accumulate in the separate
local discovery database. Do not commit live reports containing third-party data.
The first live Pacsun trial returned ten candidates with image URLs and quoted
prices, but zero resolved merchant URLs. Its normalized report is preserved;
raw responses were not available from that earlier version. This demonstrates
retrieval, not verified product coverage or working purchase links.

### Product-link metadata experiment

Extract suggestions from HTML you are authorized to supply:

```sh
python3 backend/catalog/link_metadata.py backend/catalog/fixtures/product-page.html --fixture \
  --url https://shop.example/jeans --output /private/tmp/dressed-link-review.json
```

The parser reads Product JSON-LD (including `@graph`), then Open Graph fallback.
Each suggested field records its method and source URL. Multiple products require
manual selection; multiple offers do not supply an arbitrary price. Variant
verification remains false. Missing/blocked pages return `manual_required`.
The input URL is preserved rather than trusting an HTML canonical redirect.
This command does **not** fetch URLs, execute page JavaScript, save to Wishlist or
prove the page's authenticity. The URL validator is for display and must not be
reused as an SSRF-safe network fetcher.

Link extraction also archives its output and upserts a `shared-link-html` candidate,
including manual-fallback records and field provenance. `--fixture` keeps synthetic
pages in the fixture database; omit it for authorized real HTML. `--output` is an
optional additional metadata copy. This does not persist the entire input HTML.

For the 30-link trial, collect ten actual URLs each from Pacsun, eBay and Depop,
recording acquisition permission, observed time and manual field checks. Include
blocked pages and ambiguous variants. Save a per-link JSON result with the command
above when HTML acquisition is permitted; otherwise record manual fallback. Do not
scrape Depop to fill the sample. The real sample and its results remain outstanding.

Run all offline catalog/experiment tests:

Google `/goto` store links are retained as `pendingOffers`, including merchant and
price evidence. They count as `pendingRedirectOffers`, never as verified merchant
URLs. Google comparison-query spaces are encoded before validation. On November
17, replaying the saved Pacsun response recovered three pending store offers for
one product, without new API calls; direct retailer-link resolution remains open.

```sh
python3 -m unittest discover -s backend/catalog -p 'test_*.py' -v
```

### Real retailer Firebase seed

`seed_retail_catalog.py` converts saved public Shopify feeds from Princess Polly,
tentree, Allbirds, and Lucy & Yak into the shared `RetailProduct` contract. It
selects ten available products for each of the eight Dressed categories, balances
retailers within each category, and excludes unknown/non-clothing product types.
Descriptions, remote photo galleries, options, variant links, prices and storefront
currencies are preserved. Other includes jumpsuits, dungarees and playsuits.

The first seed is stored in **out-fitted / catalogProducts**. Each document has
`id`, `category`, `retailer`, `productURL`, `title`, `imageURL`, `source`, `status`,
and a nested `retailProduct`. `status=needsReview` and `requiresReview=true` do not
mean ownership or wishlist confirmation. Photos remain remote, reuse unreviewed.
The live feeds were retrieved successfully; individual HTML page checks returned
HTTP 429, so records explicitly retain `product_page_not_verified`.

Local source responses, all normalized qualifying products, the 80-item manifest,
link-check results, Firebase commit receipt and readback verification are saved
under the gitignored `local-data/retailer-seed/` directory. Keep that directory to
retain acquisition evidence. Prices and availability are observations, not a live
checkout guarantee. Lucy & Yak's captured storefront currency is GBP; the other
three are USD.

```sh
python3 backend/catalog/seed_retail_catalog.py backend/catalog/local-data/retailer-seed
# Default is validation only. Requires an existing gcloud login for --apply.
python3 backend/catalog/upload_catalog_seed.py \
  backend/catalog/local-data/retailer-seed/seed-manifest.json --project out-fitted
# Add --apply to create missing records and verify every record by reading it back.
```

The uploader only creates missing catalog documents, refuses to overwrite differing
existing records, and accepts identical records on retry. It does not deploy rules,
modify private closet collections, or configure the SwiftUI client. The separate client integration is described below.

The app now reads this seed through `FirebaseCatalogService` on normal launches.
Discovery → For You → Shop retailers shows a mixed shelf; See all searches titles,
retailers, brands and categories. The catalog is read-only for signed-in clients;
client writes and guest reads are denied. The first version is bounded to 200
products, with the richer `RetailProduct` retained in each presentation record.

## Catalog pack for matching (local evaluation)

`build_catalog_pack.py` turns the Livostyle snapshot above into cut-out product images plus a matching index. For each product it prefers a gallery photo with no person (cut out with Apple's foreground mask) and otherwise cuts the garment off the model photo with the [parsing model](../recognition/README.md#clothes-parsing-evaluation-only); products with no usable outline are skipped. Vectors are Apple feature prints (revision 2) of each cutout on white, produced by the same Swift code the app uses.

```sh
python3 backend/catalog/build_catalog_pack.py /private/tmp/dressed-livostyle-products.json \
  /private/tmp/dressed-ml/pack --model /private/tmp/dressed-ml/ClothesParser.mlpackage
python3 backend/catalog/evaluate_catalog_pack.py /private/tmp/dressed-ml/pack \
  --model /private/tmp/dressed-ml/ClothesParser.mlpackage
```

Run a Debug simulator build with `-catalogPackPath /private/tmp/dressed-ml/pack` while `local_service.py --apple-vision` is running (it computes each piece's vector). Devices compute vectors themselves; a pack folder named `CatalogPack` in the app bundle is picked up, but none is committed.

The dataset is MIT licensed, but reuse of the product images and of edited copies is unreviewed. Keep packs local: do not commit, upload or ship them. Nothing here writes to Firebase or Cloud Storage, and `upload_catalog_seed.py` still accepts only the original 80-product seed.


November 27, 2026 run: 907 products (tops 249, dresses 250, pants 216, accessories 79, outerwear 57, skirts 38, shoes 18). Skirts, shoes and outerwear are limited by this single source (35 shoes also had no usable outline), far below the 150-300 per category in the plan. 206 cutouts came from product-only photos and 701 from model photos; some have holes where hair or arms covered the garment, and some are fragments or fabric close-ups.

`evaluate_catalog_pack.py` reported 70% top-3 and 62% top-1 over 50 queries (pants 36% top-3), excluding the retailer's square copies. **Do not treat this as passing the matching gate.** This source's galleries are largely crops and variants of one photograph, so many queries are nearly the indexed image. Accuracy on a person's own photo is unmeasured and likely lower. A valid test needs separately photographed products. In simulator spot checks, tee, jeans, sneaker and blouse matches were plausible; a headscarf matched earrings and sunglasses because the catalog has no similar item.
