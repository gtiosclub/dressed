# Garment recognition experiment

## Simulator test flow

The Debug iOS app can send a photo to a **loopback-only** development service when the user taps “Find Pieces with Google” in Camera review. The service returns Object Localization boxes as unselected piece suggestions. The app shows each crop, lets the user edit its name/category/region, add a missed piece, or return to manual entry. Only selected pieces are saved to the local prototype closet. This is a simulator test path, not a deployed or authenticated backend. On a physical iPhone, `127.0.0.1` points at the phone and will not reach the Mac.

From the repository root, start a no-charge fixture service:

```sh
python3 backend/recognition/local_service.py --fixture backend/recognition/fixtures/object-localization-response.json
```

Paid Google Vision calls are currently paused. The live command below exits before starting a service; keep using fixture mode while spending controls are reviewed:

```sh
python3 backend/recognition/local_service.py --live --project dressed-511821
```

Before the pause, the live service used the local Google Cloud CLI identity and explicitly quota-charged `dressed-511821`; no token or private key entered the app. It bound only to `127.0.0.1:8765`, accepted images up to 5 MB, and shared the CLI's ten-request lifetime reservation ledger. The project's $5 monthly budget is an **alert**, not an enforced spend cap; its 1 request/minute Vision quota only throttles requests. As of October 16, 2026, Google Cloud's enforced spend-cap budgets do not cover Cloud Vision. The live service and CLI now reject paid requests by default, the running live service was stopped, and `vision.googleapis.com` was disabled in `dressed-511821`. Re-enabling that API alone will not bypass the local code guard. The fixture mode does not call Google and its labels may not match the selected photo. Product Search matching remains separate because `dressed-511821` has no indexed product set. A prior live HTTP check through this service returned three unselected Dress candidates for Google's public sample image.

The response adapter suppresses highly overlapping detections in the same category. When it finds exactly two nearby, comparably sized shoes, it offers one unselected “Shoes” candidate spanning the pair. Review the crop: a larger rectangular box can include background, and other pair arrangements may stay separate. The app's manual outline editor can create a transparent cutout after review.

`object_localization.py` is a fixture-driven adapter for Google Vision Object Localization responses. It maps recognized garment labels and normalized boxes into **unselected** review candidates with draft-scoped IDs. General objects such as a person are ignored. It makes no cloud call. This lets the team measure whether a generic object detector finds separate pieces before deciding on a hosted service or changing the iOS import flow.

Run the synthetic outfit fixture and its evaluation:

```sh
python3 backend/recognition/object_localization.py \
  --import-id synthetic-outfit-1 \
  --response-file backend/recognition/fixtures/object-localization-response.json
python3 backend/recognition/evaluate.py \
  --provider object-localization \
  --manifest backend/recognition/fixtures/object-localization-evaluation.json
```

The synthetic response contains a shirt, pants, and a person. Its manual annotation also contains shoes; the example report therefore records one miss. These numbers test parsing and scoring, not model quality. For a real comparison, save consented development responses outside Git and point a manifest at them. The `responseFile` path is relative to the manifest. The parser keeps raw provider labels and confidence for review but never treats confidence as product identity. Box crops, masks, and app integration remain separate work.

**Live smoke check, October 16, 2026:** On the `dressed-511821` development project, one inline-image Object Localization request using the [three-dress image in Google's Product Search documentation](https://docs.cloud.google.com/vision/product-search/docs/searching-response) returned three `Dress` labels and three separate, unselected `dresses` candidates. Scores were about 0.90–0.91. The documented `gs://cloud-ai-vision-data/...` URI failed with `Error opening file`; fetching the public documentation image over HTTPS and sending its bytes inline worked. This verifies the request and adapter on one public sample, not accuracy on user photos. No live Product Search match was tested because this project has no indexed product set.

`product_search.py` is a developer-only adapter for Google Vision Product Search. It turns localized product boxes into **unselected** import candidates and attaches up to three visually similar products from the local, active catalog. It does not save clothing, create outfits, expose an HTTP endpoint, or run from the iOS app. A missing box yields `noDetection` so the app can keep its manual entry path. The response is a proposed handoff shape, not an implemented app contract.

For a side-by-side fixture run, ingest the catalog as below, then add `--compare-object-localization` and use `fixtures/combined-vision-response.json` as `--response-file`. This prints independent Product Search and Object Localization candidate lists from one response. With a configured product set and Application Default Credentials, the same flag requests both Vision features in **one** live call on a synthetic or consented image. Add `--response-output /private/tmp/vision-response.json` to save the raw response for later annotation scoring; choose a new path outside Git. Google charges for each requested feature even when they share one HTTP request. The app does not call this CLI.

## Run without a cloud account

From the repository root:

```sh
python3 backend/catalog/catalog.py --db /private/tmp/dressed-recognition-demo.sqlite ingest backend/catalog/fixtures/demo-feed.json
python3 backend/recognition/product_search.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --import-id demo-1 \
  --response-file backend/recognition/fixtures/combined-vision-response.json \
  --compare-object-localization
python3 -m unittest discover -s backend/recognition -p 'test_*.py' -v
python3 backend/recognition/evaluate.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --manifest backend/recognition/fixtures/evaluation-example.json
```

The saved response is synthetic. Its two item boxes resolve to the fixture catalog's shirt and pants. The `.example` URLs are demonstration data, not shopping links. A whole-image box is ignored because it does not isolate a garment. An unknown or inactive catalog ID produces no product link. The suggested name is a generic category name, not a claimed exact product.

The evaluation example has three annotated garments and two fixture detections, so it reports one missed shoe. This only checks the scoring code; it says nothing about Google's accuracy on real photos. To evaluate real output, save each API response as JSON and add a sample to a manifest with its `importId`, response path, and manually drawn normalized `boundingBox` plus Dressed `category` for each garment. The evaluator pairs boxes at intersection-over-union ≥ 0.5 and reports localization precision/recall, category accuracy on paired boxes, and per-category misses. Keep private test images and real response JSON outside Git.

## One live developer request

Local prerequisites: Google Cloud CLI and a Python environment with `google-auth`. On macOS, install the CLI with `brew install --cask gcloud-cli`. An isolated environment can be made with `uv venv /private/tmp/dressed-recognition-venv --python python3` and `uv pip install --python /private/tmp/dressed-recognition-venv/bin/python google-auth`. Use that environment's Python for the command below. After selecting a dedicated billed test project and enabling `vision.googleapis.com`, sign in with `gcloud auth login`, run `gcloud config set project PROJECT_ID`, then `gcloud auth application-default login` and `gcloud auth application-default set-quota-project PROJECT_ID`. These commands keep credentials in the user's local Google Cloud configuration, outside the repository. Do not paste credentials or access tokens into GitHub issues.

Create a dedicated Google Cloud project and an `apparel-v2` Product Search set with reference images you have permission to use. Set each Google product ID to the corresponding 24-character ID from the local catalog; otherwise the box may be returned but its product matches will not resolve. Wait for the set to index. The current fixture catalog has no image assets and cannot be uploaded as a real product set by itself.

With Application Default Credentials and `google-auth` installed, run:

```sh
/private/tmp/dressed-recognition-venv/bin/python backend/recognition/product_search.py \
  --db /private/tmp/dressed-recognition-demo.sqlite \
  --import-id private-draft-id \
  --image /path/to/consented-test-image.jpg \
  --product-set projects/PROJECT_ID/locations/LOCATION_ID/productSets/PRODUCT_SET_ID \
  --compare-object-localization \
  --response-output /private/tmp/vision-response.json
```

The live CLI is currently paused and rejects this command before the provider call. If a future spending arrangement allows live tests, the CLI is designed to make **one** Vision API request with Product Search and, when the comparison flag is present, Object Localization. It sends image bytes to Google, accepts images up to 5 MB, and prints only JSON metadata. The optional response file contains provider metadata but no input photo; keep it outside Git. Use synthetic or consented images; do not route real user photos through this prototype. Keep credentials in ADC, outside the repository and the iOS client. The CLI also reserves one of **10 lifetime live calls** in `~/.local/state/dressed-recognition/live-requests.json` before each request; a failed call still consumes a reservation. Fixture runs use none. This local guard does not limit other tools or cloud charges. Product Search, Object Localization, and Cloud Storage billing need separate controls; an alert-only budget does not enforce a $5 ceiling.

The `importId` should be the existing private draft ID. Candidate IDs are deterministic for the same response after sorting boxes, but a changed provider response can change the set or order. A future import coordinator must persist the first response for safe retries and require explicit selection before saving. The similarity score is only a ranking hint. It never proves exact identity, and product URLs must come from a reviewed catalog source.

## Next integration gates

1. Assemble a small consented set of single garments, worn outfits, flat lays, and overlapping clothes. Record missed pieces and incorrect boxes against manual annotations.
2. Import a small approved image catalog with IDs matching the local catalog and run a bounded live comparison. Confirm Google processing terms before using user photos.
3. Put this adapter behind an authenticated backend and a private, expiring image handoff. Add owner checks and request limits before exposing it to the app.
4. Extend the native review flow to show each candidate crop, approve/skip choices, corrections, and a no-detection manual fallback. Persist the draft result before any closet writes.

Google's [response guide](https://docs.cloud.google.com/vision/product-search/docs/searching-response) describes per-product boxes; its [quickstart](https://docs.cloud.google.com/vision/product-search/docs/create-product-set-search-products) covers product sets, import, and indexing. See [pricing](https://cloud.google.com/vision/product-search/pricing) and [budget behavior](https://docs.cloud.google.com/billing/docs/how-to/budgets) before live calls.
