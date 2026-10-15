# Garment recognition experiment

`product_search.py` is a developer-only adapter for Google Vision Product Search. It turns localized product boxes into **unselected** import candidates and attaches up to three visually similar products from the local, active catalog. It does not save clothing, create outfits, expose an HTTP endpoint, or run from the iOS app. A missing box yields `noDetection` so the app can keep its manual entry path. The response is a proposed handoff shape, not an implemented app contract.

## Run without a cloud account

From the repository root:

```sh
python3 backend/catalog/catalog.py --db /private/tmp/dressed-recognition-demo.sqlite ingest backend/catalog/fixtures/demo-feed.json
python3 backend/recognition/product_search.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --import-id demo-1 \
  --response-file backend/recognition/fixtures/product-search-response.json
python3 -m unittest discover -s backend/recognition -p 'test_*.py' -v
python3 backend/recognition/evaluate.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --manifest backend/recognition/fixtures/evaluation-example.json
```

The saved response is synthetic. Its two item boxes resolve to the fixture catalog's shirt and pants. The `.example` URLs are demonstration data, not shopping links. A whole-image box is ignored because it does not isolate a garment. An unknown or inactive catalog ID produces no product link. The suggested name is a generic category name, not a claimed exact product.

The evaluation example has three annotated garments and two fixture detections, so it reports one missed shoe. This only checks the scoring code; it says nothing about Google's accuracy on real photos. To evaluate real output, save each API response as JSON and add a sample to a manifest with its `importId`, response path, and manually drawn normalized `boundingBox` plus Dressed `category` for each garment. The evaluator pairs boxes at intersection-over-union ≥ 0.5 and reports localization precision/recall, category accuracy on paired boxes, and per-category misses. Keep private test images and real response JSON outside Git.

## One live developer request

Create a dedicated Google Cloud project and an `apparel-v2` Product Search set with reference images you have permission to use. Set each Google product ID to the corresponding 24-character ID from the local catalog; otherwise the box may be returned but its product matches will not resolve. Wait for the set to index. The current fixture catalog has no image assets and cannot be uploaded as a real product set by itself.

With Application Default Credentials and `google-auth` installed, run:

```sh
python3 -m pip install google-auth
python3 backend/recognition/product_search.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --import-id private-draft-id \
  --image /path/to/consented-test-image.jpg \
  --product-set projects/PROJECT_ID/locations/LOCATION_ID/productSets/PRODUCT_SET_ID
```

The CLI makes **one** Product Search request, sends the image bytes to Google, accepts images up to 5 MB, and prints only JSON metadata. It does not store the input photo. Use synthetic or consented images; do not route real user photos through this prototype. Keep credentials in ADC, outside the repository and the iOS client. Product Search and Cloud Storage billing should be watched in the dedicated project; an alert-only budget does not enforce the $10 ceiling. Delete the test project when the experiment ends.

The `importId` should be the existing private draft ID. Candidate IDs are deterministic for the same response after sorting boxes, but a changed provider response can change the set or order. A future import coordinator must persist the first response for safe retries and require explicit selection before saving. The similarity score is only a ranking hint. It never proves exact identity, and product URLs must come from a reviewed catalog source.

## Next integration gates

1. Assemble a small consented set of single garments, worn outfits, flat lays, and overlapping clothes. Record missed pieces and incorrect boxes against manual annotations.
2. Import a small approved image catalog with IDs matching the local catalog and run a bounded live comparison. Confirm Google processing terms before using user photos.
3. Put this adapter behind an authenticated backend and a private, expiring image handoff. Add owner checks and request limits before exposing it to the app.
4. Extend the native review flow to show each candidate crop, approve/skip choices, corrections, and a no-detection manual fallback. Persist the draft result before any closet writes.

Google's [response guide](https://docs.cloud.google.com/vision/product-search/docs/searching-response) describes per-product boxes; its [quickstart](https://docs.cloud.google.com/vision/product-search/docs/create-product-set-search-products) covers product sets, import, and indexing. See [pricing](https://cloud.google.com/vision/product-search/pricing) and [budget behavior](https://docs.cloud.google.com/billing/docs/how-to/budgets) before live calls.
