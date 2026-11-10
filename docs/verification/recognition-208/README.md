# #208 recognition verification

Branch: `208-data-p15---keep-recognition-going-when-you-leave-dressed-and-speed-it-up`.
Measurements were taken from the local implementation based on `1107815`, not an unmodified
baseline checkout. Raw JSON from 22 experiment and smoke reports is retained locally outside
this PR. The comparison screen exports fresh JSON for independent reproduction.

## Current Release pilot

Signed Release app without an attached debugger, iPhone 18 Pro **simulator**, iOS 27.0
(24A434), Xcode 27.0. Implementation: `scanline-v3-simulator-cpu-classifier`.
One first-use pair is excluded, followed by five interleaved repeated pairs per input.
Both modes use the same supported CPU for classification. Positive change means slower.

| Input | Original median | Trial median | Change |
| --- | ---: | ---: | ---: |
| Public single dress | 273.16 ms | 278.03 ms | +1.8% |
| Public multi-dress | 1589.77 ms | 1454.57 ms | -8.5% |
| Synthetic silhouette | 384.35 ms | 352.76 ms | -8.2% |

This is one pilot session, not a universal or physical-phone speedup. Totals include preparation,
recognition and cutouts, excluding file persistence, rendering and the old screen's duplicate
classifier. Classification executes, but body pose and foreground masking fail on this runtime.
All samples still produced one generic unselected `Piece / other`; the multi-dress input did
not become separate garment candidates. All 18 original/trial cutout pairs, including first use,
had matching SHA-256 digests. Output equality does not establish garment accuracy.

## Earlier experiments

An eager-decode trial regressed on the large synthetic input; removing the extra decode fixed
that regression. An arithmetic-only trial was nearly flat. The later pinned-buffer scanline
implementation showed 21–29% lower synthetic median total time across two sessions when all
Vision requests, including classification, failed quickly. Small-photo results were mixed.
Those historical fallback-only totals cannot describe the current classifier-inclusive speedup.
Raw reports for the negative and positive experiments were preserved together.

## Inputs and reproduction

Two public development photos come from Google's
[Product Search response examples](https://docs.cloud.google.com/vision/product-search/docs/searching-response):
[single dress, 305 × 400](https://docs.cloud.google.com/static/vision/product-search/docs/images/quickstart-search_for_matching_images_SML.jpg)
and [multiple dresses, 640 × 231](https://docs.cloud.google.com/static/vision/product-search/docs/images/searching-response-search_response_multi_detection.jpg).
The third input is the generated 1200 × 1600 `RecognitionDemoImage` silhouette. These are
small development samples, not a held-out accuracy set. No input photos are committed.

See the [performance guide](../../recognition-speed-demo.md) for paired comparisons, JSON export,
Release configuration and tests, and the [environment investigation](vision-environment.md) for
Vision failures and remaining gates. The standalone Speed Lab uses the same shared sources.

## Verification — November 4, 2026

- Main and standalone Release simulator builds succeeded.
- Fresh selected suite: all 11 logic tests and all seven ShareImport UI tests passed, zero failures.
- Tests cover pixel/orientation behavior, exact fallback PNG equivalence, cancellation, draft
  restart and merge rules, interrupted-draft recovery, comparison controls and review/save flows.
- The demo uses synthetic images and a mock session. The first recognition attempt has a
  controlled delay; relaunch uses the real on-device service. Video Debug timings demonstrate
  the comparison UI and must not be quoted as Release performance evidence.
- SwiftLint was unavailable. Real authentication, physical-device timing, category/cutout
  quality, peak memory and successful body-pose/mask inference remain unverified.
- The trial remains off by default. Completion while the app is closed is not promised.
