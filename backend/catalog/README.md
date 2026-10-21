# Local retailer catalog prototype

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

Before adding a live retailer connector, move approved source configuration out of the untrusted feed, confirm access and image-use terms, cap refresh frequency, and provide an authenticated backend deployment. Do not expose the local development server publicly.

## Saved eBay Browse response adapter

`ebay_browse.py` converts a **saved** eBay US Browse `item_summary/search` JSON response into this catalog's partial feed. It fixes the eBay product and image host allowlists in code, validates item IDs, prices, and URLs, and keeps a stable ID based on eBay's `itemId`. The Dressed category is an explicit operator choice; the source category remains separate. A keyword result is always a partial scan, so absent listings are not marked stale. This is a response adapter, not a live retailer connection or an exact product matcher.

Try it with synthetic data, without making an API request:

```sh
python3 backend/catalog/ebay_browse.py backend/catalog/fixtures/ebay-browse-response.json --category shoes --db /private/tmp/dressed-ebay-demo.sqlite
python3 backend/catalog/catalog.py --db /private/tmp/dressed-ebay-demo.sqlite search --category shoes
```

The fixture's eBay-shaped links are not real listings. Production use requires eBay Buy API access and a reviewed right to store and display its content. eBay's published daily API call limit is a rate limit, not a dollar cap. The adapter has no token handling, network request, schedule, or paid call path; live access stays off until credentials, terms, retention, and spending controls are resolved. Never put an application token or client secret in the iOS app or repository.
