# Photo-to-product search: review and testing

This is a **Debug simulator prototype**, not a hosted service. Camera/photo-library review and shared-photo review offer **Find similar products** for each candidate. The next sheet previews the crop and requires **Search this crop** before uploading. Results show source image/name/domain/price when available and always say **Similar**. Wishlist uses the existing explicit review/confirmation flow. Nothing changes `ClothingItem`, detection, Firebase configuration, or the public Discovery catalog.

## Reviewer map

1. `service.py`: standard-library SerpAPI upload/search adapter, normalization, retailer-domain filtering, bounded attempts and retry cache. One process, loopback only, no cloud deployment.
2. `dressed/Common/Models/ProductSearchSchema.swift`: transient response; no persisted schema change.
3. `dressed/Discovery/ViewModels/ProductSearchService.swift`: injected client, image preparation and state. `Discovery/Views/ProductSearchResultsView.swift`: crop confirmation, results and Wishlist handoff.
4. Both existing Camera review views add one reusable action. `ChoosePhotoButton` stays unchanged. App files use Xcode's existing synchronized folder; no project/package edits.
5. `test_service.py` and the three `testProductSearch…` methods in `dressedUITests/ShareImportUITests.swift` cover backend and native behavior. `compare.py` runs fresh searches against the same development-photo manifest and existing catalog text baseline.

The broader [proposal](../../docs/photo-product-search-plan.md) describes later OpenCLIP ranking and hosted authentication. To keep this merge small, this implementation uses the existing category/name catalog baseline instead of introducing model dependencies. No real feed or SerpAPI key was supplied, so live relevance, product-link quality, prices, latency and cost remain unmeasured. Fixtures are explicitly labeled and their `.example` links are not shopping links.

## Try the app without a key

From the repository root, keep this running in a terminal:

```sh
python3 backend/product_search/service.py --fixture backend/product_search/fixtures/lens.json
```

Open `dressed.xcodeproj`, choose the `dressed` scheme, **Debug**, and an iOS 18+ iPhone simulator. Build/run normally with signing; do not set `CODE_SIGNING_ALLOWED=NO` for interactive Firebase login. No app API key or new package is needed.

1. Sign in with your development account using the normal sign-in screen. This repository documents the process but does not contain test credentials.
2. Camera → Choose photo → select a development clothing photo. Wait for suggestions, or add a missed piece manually.
3. Adjust the image region so only the intended garment is shown. Tap **Find similar products**, inspect the preview, then **Search this crop**.
4. Expect the **Fixture — not live shopping results** label, a blue sweater with `$49.00`, and a cardigan with no invented price. Missing images show a photo placeholder.
5. Tap **Review for Wishlist**. Saving stays disabled until you enter a name and explicitly select the Wishlist confirmation. Cancel to avoid saving fixture links. Close results: the garment's closet selection is unchanged.
6. Stop the backend with Ctrl-C, reopen search, and verify the error and Retry action. Manual import must still work.
7. Restart with `--fixture backend/product_search/fixtures/empty.json`; reopen search and verify the empty state. Repeat through a shared-image draft when App Group signing is available.

The action is intentionally absent on physical devices and in Release builds. A phone cannot reach the Mac through `127.0.0.1`. Do not expose this development server to a LAN or the internet.

## Enable real SerpAPI searches

1. Create a [SerpAPI account](https://serpapi.com/) and obtain its API key. Confirm your account's [plan and usage limits](https://serpapi.com/pricing). Do not enable automatic renewals just for this test.
2. Stop the fixture server. In **zsh**, enter the key without putting it in shell history or the repository:

   ```sh
   read -s "SERPAPI_API_KEY?SerpAPI API key: "
   export SERPAPI_API_KEY
   python3 backend/product_search/service.py --live \
     --allowed-host nike.com --allowed-host uniqlo.com --max-requests 20
   ```

3. Repeat the app flow using development images permitted for third-party processing. Add other reviewed retailer domains with repeated `--allowed-host` arguments. Filtering limits coverage; an allowed retailer domain does not prove that a result is a purchasable product page.
4. Check each real source page manually: correct product/model, retailer, current price/stock and working link. Record wrong matches and missing information. Product identity always remains **Similar** in this slice.
5. Stop the service and run `unset SERPAPI_API_KEY` when finished. Never put this key in Swift, Info.plist, Firebase client configuration, screenshots, committed JSON or a PR.

The service sends a JPEG through SerpAPI's [Image API](https://serpapi.com/image-api), then uses [`google_lens` / `visual_matches`](https://serpapi.com/google-lens-visual-matches-api). UIKit redraws/compresses the crop to at most 450 KB, stripping metadata; SerpAPI permits 500 KB. The provider image ID expires after ten minutes, which does **not** establish provider data-deletion guarantees. Review processing/retention before real-user use. No public image-hosting bucket is needed.

The backend counts every attempted provider operation, including errors, toward `--max-requests`. Successful retries with the same request ID and bytes reuse a ten-minute cache; different bytes with the same ID return 409. Reopening the sheet creates a new request and may consume another search. Cancellation cannot reverse an already sent provider request. There are no automatic provider retries, follow-up enrichment calls or pagination. No request bodies, keys or provider URLs are logged or written to disk.

## Catalog comparison

Obtain a current retailer CSV/JSON export with permission to process its product images and display its links. Map it to the existing [catalog feed contract](../catalog/README.md), import it, and retain its capture date. A synthetic feed only tests wiring.

Create a manifest **outside Git**, next to prepared JPEG crops (each <= 500 KB):

```json
[
  {"id": "shoe-01", "imagePath": "shoe-01.jpg", "query": "sneaker", "category": "shoes"},
  {"id": "top-01", "imagePath": "top-01.jpg", "query": "sweater", "category": "tops"}
]
```

Use ordinary reviewed descriptions, not ground-truth product names. Run while the live bridge is active:

```sh
python3 backend/catalog/catalog.py --db /private/tmp/dressed-products.sqlite ingest /path/to/approved-feed.json
python3 backend/product_search/compare.py \
  --manifest /path/to/development-photos/manifest.json \
  --db /private/tmp/dressed-products.sqlite \
  --output /private/tmp/dressed-product-comparison.json
```

The report preserves paired results, errors, input hashes and timings. Lens searches the crop; the explicitly labeled catalog baseline uses that crop's reviewed text/category. This is not a visual-embedding comparison or an automatic accuracy score. The catalog retains existing active-status filtering; check `lastCheckedAt`, stock and price manually. Annotate the top five per photo for useful alternative/wrong product/verified identity/unjudgeable, check links and metadata, and repeat after 24–48 hours. Keep absent-catalog photos in coverage counts. Use the [proposal's evaluation checklist](../../docs/photo-product-search-plan.md#evaluation-appendix-what-completes-the-task) before claiming the original research ticket complete.

## Automated tests

```sh
python3 -m unittest discover -s backend/product_search -p 'test_*.py' -v
```

The HTTP test binds only loopback. Start these two services in separate terminals for native tests; leave port **8769 unused**:

```sh
python3 backend/product_search/service.py --fixture backend/product_search/fixtures/lens.json --max-requests 100
python3 backend/product_search/service.py --fixture backend/product_search/fixtures/empty.json --port 8768 --max-requests 100
```

Find your simulator UUID with `xcrun simctl list devices available`, then:

```sh
xcodebuild -project dressed.xcodeproj -scheme dressed -configuration Debug \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /private/tmp/dressed-product-search-build \
  -parallel-testing-enabled NO \
  -only-testing:dressedUITests/ShareImportUITests/testProductSearchResultsRequireWishlistReview \
  -only-testing:dressedUITests/ShareImportUITests/testProductSearchEmptyResults \
  -only-testing:dressedUITests/ShareImportUITests/testProductSearchUnavailableCanRetryAndClose \
  -only-testing:dressedUITests/ShareImportUITests/testSelectTop \
  -only-testing:dressedUITests/ShareImportUITests/testReviewSelectTwoSkipOneSaveOutfitAndReopen test
```

These isolated UI tests use the repository's existing mock session and shared-photo fixture. They do not verify Firebase authentication or SerpAPI quality. Manual acceptance uses normal sign-in. Server host/origin checks protect the local prototype from browser requests; they are not Firebase authorization. Hosting needs token verification, owner-scoped caches, quotas and image validation before release.

## Commit it yourself

Verification on November 10, 2026: the normally signed Debug build passed on
iPhone 17 Pro / iOS 26.5 (Xcode 27.2). All **8 backend tests** and **5 selected
XCUITests** above passed. The captured results screenshot was visually inspected;
crop preview, fixture attribution, source, optional price and Wishlist action
were visible. A final rebuild after removing a concurrency warning also passed.
Normal launch without mock flags reached Sign In; no development-account
credentials were supplied, so real authentication and photo-library acceptance
remain unverified. SwiftLint was not installed. Live SerpAPI, real catalog quality,
Release builds and physical devices were not tested.

Local test artifacts (not committed):
`/private/tmp/dressed-product-search-tests.xcresult`,
`/private/tmp/dressed-product-search-tests.log`, and
`/private/tmp/dressed-product-search-screenshots/`.

Review all local edits first; the branch already contains the architecture proposal from the earlier planning step. Stage only these paths:

```sh
git status --short
git diff --check
git add backend/product_search \
  dressed/Common/Models/ProductSearchSchema.swift \
  dressed/Discovery/ViewModels/ProductSearchService.swift \
  dressed/Discovery/Views/ProductSearchResultsView.swift \
  dressed/Camera/Views/PrototypeImportView.swift \
  dressed/Camera/Views/SharedImportReviewView.swift \
  dressedUITests/ShareImportUITests.swift \
  docs/README.md docs/architecture.md docs/photo-product-search-plan.md
git diff --cached --stat
git diff --cached
git commit -m "Add reviewed photo-to-product search prototype"
```

No commit or push is performed by the implementation agent. Keep keys, development photos, real response reports, `.xcresult` bundles and derived build output outside Git.
