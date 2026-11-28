# Standalone Dressed Speed Lab

Choose the **DressedSpeedLab** scheme in `dressed.xcodeproj` to run the recognition
benchmark without the main app's sign-in, App Group or Share Extension setup.
This target compiles references to the same recognition, image-handling and benchmark
sources used by Dressed; it does not copy or fork the implementation. It has its own
bundle identifier (`com.jneal47.dressed.speedlab`) and no Firebase dependency or App Group
entitlement. The default Run configuration is Release without a debugger.

The app opens directly to **On-device speed test**. Choose a development photo or the
synthetic input, run the comparison, inspect warnings and previews, and export the timing
JSON. It does not save closet items or change the main app's import preference. Reports include the application identifier and Vision
execution policy so results from different targets/environments can be distinguished.

## Simulator

```sh
xcodebuild -project dressed.xcodeproj -scheme DressedSpeedLab -configuration Release \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath /private/tmp/dressed-speed-lab \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
```

Current iOS 27 simulator classification uses an explicitly supported CPU. Body pose and
foreground masking still fail there. See the [environment investigation](../../docs/verification/recognition-208/vision-environment.md).
These conditions do not establish physical-device speed or garment accuracy.

## Optional independent device verification

All account/device steps are performed by the person running the check:

1. Select the **DressedSpeedLab** target under Signing & Capabilities and choose your own
   development signing team. The target has no group capabilities to provision. If Apple
   reports an identifier conflict, use another unique development bundle identifier.
2. Select your compatible device, then run the **DressedSpeedLab** scheme. The app still
   requires the existing iOS 18 minimum; it does not require exactly iOS 18.
3. Use public/development clothing images and compare Original with the trial. Check
   categories, missed garments and edges as well as timings. Keep input/device/OS consistent.
4. Export timing JSON if you want to share measurements. It includes timings, automatically
   generated labels, hashes and execution metadata, with no input or cutout image bytes.

Device builds keep automatic Vision compute selection. Physical signing, installation,
inference behavior, memory and timing have not been verified by the simulator checks.
