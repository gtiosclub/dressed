# On-device recognition performance — #208

Scope agreed with Neal: keep recognition on the phone, prioritize measured processing speed,
and keep leave/return checks secondary. There are no recognition uploads, queues, workers or
microservices in this implementation. The legacy fixture client remains in the repository but
neither the import flow nor the benchmark calls it.

## Standalone verification target

The **DressedSpeedLab** scheme builds a separate app from the same recognition sources,
with no Firebase or App Group dependency. It opens directly to the comparison screen and
uses Release without a debugger by default. It does not change Dressed's import preference.
See [standalone setup](../tools/RecognitionLab/README.md). The target can be run independently;
any optional physical signing/installation is performed by its operator.

## Open the benchmark

In Xcode, open `dressed.xcodeproj`, select the `dressed` scheme and an available compatible
iPhone or simulator. A phone does not need to run exactly iOS 18; it must support the app's
existing iOS 18 minimum. Build and run normally.

- Debug: sign in with your development account, open **Camera → On-device speed test**.
- For an isolated diagnostic, enable the preconfigured `-recognitionLab` scheme Run argument. This opens
  only the diagnostic, without pretending to sign in or exposing any closet records. It works
  with Release as well as Debug. Remove the argument to return to the normal app.
- Choose a development clothing photo, select **Native pixels + reuse**, and tap **Run comparison**.
  The synthetic silhouette is for geometry/fallback checks only, not model accuracy.
- Keep **Use native processing in imports (trial)** off until physical-phone speed and quality
  checks pass. Turn it on to try the variant in real imports; turn it off to revert.
- Scroll to **Measured wall time**, expand each run for stage timings and warnings, and compare
  the category and cutout previews. Use **Export timing JSON (no photos)** to retain the result.
- **Stop comparison** cancels the remaining work and retains completed measurements. Cancellation
  waits for an in-flight synchronous Vision request to finish; its stale result is then rejected.

The lab never writes a draft, closet item, outfit or source photo. Its temporary JSON contains
timings, generic suggestion labels/IDs, input/output digests, byte counts, build/OS/device information
application identifier, Vision compute policy and thermal state. It contains no image bytes. The system Photos picker controls photo access.

## Current verification status

The simulator CPU workaround now lets classification execute. Human body-pose detection and
Apple's foreground mask still fail in this environment, including in a fresh simulator.
The public sample inputs have not passed garment-recognition accuracy checks; they still
fall back to `Piece / other`. Simulator execution success does not establish accurate labels. Shared-draft termination/relaunch
recovery is also covered by a native UI regression test, including a manual selected piece.

[Current diagnosis and classification-inclusive Release measurements](verification/recognition-208/vision-environment.md)
record what works, what fails and the unsuccessful iOS 18.6 runtime download attempt. The
older fallback-only measurements below are retained as history, not the current total speedup.

## What changed

1. **Avoid enlarged crops.** The original crop renderer inherited the screen scale; a half-width
   crop from a 1200-pixel source could become 1800 pixels on a 3× simulator. Native mode decodes
   and orients the source once when regions need crops, then prepares them at source pixel resolution.
   Review/saving also
   uses an explicit scale of 1. The source photo is unchanged.
2. **Reuse work.** Whole-image fallback skips the extra native decode and preserves the
   original JPEG preparation; a regression test checks exact byte equality. Native mode reuses a crop
   within the same run and a Core Image context across
   successful foreground masks. It keeps whole-image classifier input unchanged. The 1024px
   downsampling option is a separate, opt-in quality trial, not the production default.
3. **Use scanline background removal.** Process connected horizontal spans instead of
   queuing individual background pixels. Pin buffers for the synchronous inner loop and release
   completed spans. The color threshold and connectivity rules stay the same. PNG-byte tests
   and per-run output hashes check equivalence. This improves the fallback, not Vision inference.
4. **Remove duplicate classification.** Camera review no longer starts a separate whole-image
   classifier at the same time as the full suggestion pipeline.
5. **Propagate cancellation.** Detached work receives cancellation; late results do not update
   review. Interrupted shared drafts now restart even when manual pieces exist, retaining those
   edits. Completed review drafts do not automatically run again.

The crop/context/fallback variant is a grouped first experiment; its total cannot establish
which individual change helped. Smaller images remain a separate trial. Imports default to
the original processing path while the phone quality/speed gate remains open; both paths
remove the old network bridge and duplicate Camera classifier.

The original benchmark mode preserves the old crop scale, separate per-crop preparation,
per-call Core Image context, and original background loop. It bypasses the old network bridge
just like all other modes. It is a comparison of processing paths, not the old screen's extra
concurrent classifier or any former network timeout.

## How to interpret the measurements

The first run of each mode is reported separately. Repeated-run medians exclude those first
runs and alternate which mode runs first. Total wall time includes preparation, recognition
and cutouts; it excludes closet saving, file persistence and screen rendering. Nested stage
durations overlap: do not add `cutout total` to its mask/fallback children.

For a credible phone comparison, use Release without the debugger, the same photos/device/OS,
at least three repeated pairs, and multiple development photos. Record thermal conditions;
do not compare a cold baseline with a warmed optimized run. Inspect small garments, crop
orientation, thin edges and overlapping clothing. The benchmark does not measure peak memory;
use Instruments before promoting aggressive size/concurrency changes. Parallel processing
has deliberately not been added without a memory/performance comparison.

Simulator Vision can fail to create its inference context. Each run records those failures
as warnings. Generic `Piece / other` output after a failed classifier is not an accuracy pass.
Fallback timings remain real image-processing measurements, but cannot establish model speed
or representative phone latency. No p95 claim is made from this small sample.

## Measured Release pilot — November 3

With simulator CPU classification executing, the current Release pilot measured:

| Input | Original median | Trial median | Change |
| --- | ---: | ---: | ---: |
| Public single dress | 273.16 ms | 278.03 ms | 1.8% slower |
| Public multi-dress | 1589.77 ms | 1454.57 ms | 8.5% faster |
| Synthetic silhouette | 384.35 ms | 352.76 ms | 8.2% faster |

One session, five interleaved repeated pairs per input, first-use pairs excluded. Body pose
and foreground masking still fail on this simulator; outputs remain generic. This does not
establish a universal recognition speedup, garment accuracy or phone performance. Imports keep
the trial off until speed, quality and resource gates pass.

[Verification summary and earlier experiment context](verification/recognition-208/README.md).
Raw benchmark history is preserved locally outside the PR; use the comparison screen to export
new measurements. Historical 21–29% synthetic gains came from fallback-only runs where
classification also failed, and do not describe the current classifier-inclusive pipeline.

## Verification commands

```sh
xcodebuild -project dressed.xcodeproj -scheme dressed -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath /private/tmp/dressed-208-build CODE_SIGNING_ALLOWED=NO \
  -only-testing:dressedTests test
```

For the complete native UI suite, preserve simulator signing/App Group entitlements:

```sh
xcodebuild -project dressed.xcodeproj -scheme dressed -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath /private/tmp/dressed-208-build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
  -only-testing:dressedTests -only-testing:dressedUITests/ShareImportUITests test
```

The new `dressedTests` target covers pixel dimensions, orientation, invalid inputs, cancellation,
byte-identical masks across topology/odd-dimension fixtures, whole-image JPEG equality,
interrupted-draft restart rules and edit/selection preservation on retry.
The new benchmark XCUITests exercise completion/results and Stop/retry controls. Existing
fixture-backed import tests remain separate from real Firebase authentication verification.
An unsigned simulator build can produce Firebase Keychain entitlement errors; use a normally
signed build for real sign-in and device demos.

For automated local input runs, copy a development image into the app's Documents directory,
then launch with `-recognitionLab -benchmarkInput filename.jpg -runRecognitionBenchmark -benchmarkRepeats 5`.
Only a filename in that app directory is accepted. The current report is
`tmp/recognition-benchmark.json` inside the app's data container. Synthetic automation uses
`-recognitionLab -syntheticRecognition -runRecognitionBenchmark -benchmarkRepeats 5`.

## Remaining checks

Real-phone model latency, category accuracy and visual quality need a physical-device run.
Do not present simulator fallbacks, synthetic samples, or a faster loading transition as a
measured improvement to the recognition model. Private photos still require explicit selection
before saving; no import automatically publishes anything.
