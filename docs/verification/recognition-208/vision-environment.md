# Current Vision environment investigation — #208

## Current status

Simulator-only CPU selection lets `VNClassifyImageRequest` execute again. The setting is
compiled only for Simulator; device builds retain automatic compute selection. It uses the
CPU listed by `supportedComputeStageDevices` and `setComputeDevice`, following
[Apple's compute-device API](https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice(_:for:)).
No deprecated CPU flag is used in the app. Framework setup time is included in classification
timing. A native regression test verifies CPU assignment and successful execution.

Successful execution is not an accuracy pass: the two public dress photos and synthetic input
still produced the generic, unselected `Piece / other` in the current app comparison. No
confidence threshold or label mapping was changed to force a positive garment result.

Body-pose detection and foreground-instance masking still fail before producing observations
on the installed iOS 27.0 simulator. This reproduced outside Dressed and on an empty simulator,
which narrows the issue beyond draft/UI coordination; the underlying runtime/host cause is
not fully identified.

## Reproduction matrix

Xcode 27.0 (27A266a), iOS 27.0 Simulator (24A434). Public single-dress test image only.

| Request | Automatic / explicit GPU | Explicit supported CPU |
| --- | --- | --- |
| Image classification | `NSOSStatusErrorDomain -1`, Espresso context creation failure | Completes, 1303 observations |
| Human body pose | `com.apple.Vision 9`, unable to set up request | Same setup failure |
| Foreground-instance mask | `com.apple.Vision 9`, inference context creation failure | CPU is not advertised for this request's compute stage |

Both a CGImage and a successfully created BGRA CVPixelBuffer were tested. Neither input
format resolved body-pose or foreground-mask setup. The old deprecated CPU-only flag was
also tried only in a temporary diagnostic, without resolving those two requests.

The official Metal Toolchain 27A266a was initially missing. It was downloaded (838.9 MB),
installed and its compiler verified. The same failures persisted after booting the empty
simulator again with the component installed. This repair did not fix Vision, and must not
be described as a proven Vision prerequisite or solution.

## Alternate runtime attempt

An additional iOS 18.6 runtime experiment was attempted. Xcode rejected OS version 18.6
with both universal and arm64 variants and also rejected published build 22G86 as unavailable.
No iOS 18.6 runtime download or installation occurred. Apple's public index still listed the
runtime, but this Xcode's downloader did not provide it. A different supported runtime/host
or a separately performed physical-device check remains necessary to validate the full path.
The original simulator and its data were retained; the extra diagnostic simulator was shut down.
No physical phone or account access is part of this investigation.

## Release run with classification executing

Archived reports are schema 4, `scanline-v3-simulator-cpu-classifier`; raw JSON is retained
locally outside this PR.
One first-use pair is excluded, followed by five interleaved repeated pairs per input. Both
modes use the same CPU-classifier policy. Positive change is slower; negative is faster.

| Input | Original median | Trial median | Change | Classifier median, original / trial |
| --- | ---: | ---: | ---: | ---: |
| Public single dress | 273.16 ms | 278.03 ms | +1.8% | 227.63 / 230.85 ms |
| Public multi-dress | 1589.77 ms | 1454.57 ms | -8.5% | 1532.41 / 1414.40 ms |
| Synthetic silhouette | 384.35 ms | 352.76 ms | -8.2% | 218.23 / 256.22 ms |

These are one pilot session with varying timings. Classification executes, while body pose
and foreground masking still use their failure/fallback paths. All 18 original/trial cutout
pairs, including first-use pairs, match by SHA-256. They remain partial-pipeline simulator
measurements, not phone performance or successful multi-garment extraction. Do not compare
these totals directly against older reports where classification failed quickly.

## Remaining gates

- Successful body-region and foreground-mask inference on a supported environment.
- Garment category/region/cutout quality on varied development and held-out images.
- Repeatable timing and peak-memory checks before enabling the grouped trial by default.
- Physical-device performance requires a separate manual check; simulator CPU timing does
  not predict phone CPU/GPU/Neural Engine timing.

## Lifecycle and independent verification

A native lifecycle XCUITest terminates Dressed while a controlled recognition service is
pending, then relaunches using the real on-device service. It verifies that processing
restarts, the manual piece keeps its name and selection, a later relaunch retains the
completed two-piece draft without duplication, and saving is enabled. The fixture session
is isolated from real authentication. Production defaults to the injected on-device adapter.

The `DressedSpeedLab` target builds only the shared recognition/benchmark sources and a small
app entry point. It has no Firebase packages, App Group entitlement or Share Extension
dependency. Its schema-5 reports identify the application bundle. A Release simulator smoke
run was retained locally as `standalone-smoke.json`; it is a functional check, not a speed study.
See [standalone instructions](../../../tools/RecognitionLab/README.md) for independent use.

## Latest verification record

The main app and standalone target both build in signed Release simulator configuration.
On November 4, a fresh build-for-testing and complete selected native suite passed: all 11
logic checks and all seven ShareImport UI flows, with zero failures. This includes the
interrupted/manual lifecycle case, comparison completion/cancellation and wishlist persistence.
Earlier scrolling and queued-share isolation corrections are included in this run. The
simulator walkthrough was recorded using synthetic fixtures and a mock session; its Debug
comparison numbers are functional evidence, not Release performance results. No real
authentication or physical-device acceptance is claimed. The standalone Release comparison
also completed and its final screen was inspected. SwiftLint remains unavailable.
