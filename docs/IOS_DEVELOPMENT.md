# iOS development and agent testing

This project uses MobileBuildMCP (the current name of XcodeBuildMCP) for simulator builds, screenshots, accessibility snapshots, taps, logs, and tests. InjectionNext is the selected hot reload engine; Inject refreshes SwiftUI views. InjectionIII and HotSwiftUI are alternatives and are not installed for this project.

## Setup on a new Mac

1. Install Xcode, select it with `xcode-select`, and install an iOS simulator runtime compatible with the project's iOS 18.0 deployment target. Open `dressed.xcodeproj` in Xcode once to resolve packages.
2. Install MobileBuildMCP using the [official installation instructions](https://github.com/getsentry/MobileBuildMCP). Check `mobilebuildmcp --version`; the tracked `.codex/config.toml` resolves the executable from your `PATH`.
3. Download the current signed [InjectionNext release](https://github.com/johnno1962/InjectionNext/releases) to `/Applications/InjectionNext.app`. This machine uses 2.0.1. The app and Swift package should be the same release. Run `xcodebuild -resolvePackageDependencies -project dressed.xcodeproj -scheme dressed`.
4. For optional InjectionNext agent tools, enable its local control server with `defaults write com.johnholdsworth.InjectionNext mcpServer -bool true`, restart the app, copy `/Applications/InjectionNext.app/Contents/Resources/mcp-server` to a writable local directory, and run `npm ci` there. Register the copied `index.js` with your own Node executable in your user-level Codex configuration. Do not commit a machine-specific path to the project configuration. The control socket is local at `/tmp/InjectionNext-control.sock`.
5. Trust this repository in Codex and start a new Codex session from the repository root so its project `.codex/config.toml` loads. `codex mcp get MobileBuildMCP` confirms registration. Optional InjectionNext registration needs a separate check on each machine.
6. Create an iPhone 17 Pro simulator with the newest runtime installed in Xcode. This Mac has a `Dressed iPhone 17 Pro iOS 27` device on iOS 27.0. If your device name differs, update `.mobilebuildmcp/config.yaml` or pass its ID to each command.

The project config in `.mobilebuildmcp/config.yaml` selects the `dressed` Debug scheme and the named iOS 27.0 iPhone 17 Pro simulator. Find its ID with `mobilebuildmcp simulator list`; use `--simulator-id` when multiple devices have similar names.

## Test account for interactive checks

Sign in through the normal app screen with a dedicated development account. Keep its credentials outside the repository and do not use personal data in that account.

Launch the app without `-mockSignedIn` or `-mockSession`. These launch flags bypass Firebase authentication and must not be used to claim the real sign-in flow works. The existing fixture-backed XCUITests use `-mockSignedIn` to isolate their import flows; run a separate real-account check for authentication and signed-in behavior.

Use a normally signed build when installing or launching the app for Firebase Auth checks. `CODE_SIGNING_ALLOWED=NO` is useful for a compile-only simulator build, but installing that output leaves it without a usable app signing identity for Keychain access. Firebase Auth can then report `ERROR_KEYCHAIN_ERROR` with `SecItemCopyMatching (-34018) A required entitlement is not present` during session restoration or login. Build without that override before installing or running:

```sh
xcodebuild -project dressed.xcodeproj -scheme dressed -configuration Debug \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /private/tmp/dressed-signed-build build
```

Check the resulting app with `codesign -dv --verbose=2 /private/tmp/dressed-signed-build/Build/Products/Debug-iphonesimulator/dressed.app`; its identifier should be `gtiosclub.dressed`. After installing it, relaunch without mock flags and confirm the Firebase Auth Keychain error is absent from simulator logs. If the error occurs on a signed physical-device build, inspect that build's signing and entitlements separately.

The iOS 27 simulator Photos library has three product photos for import checks: a [blue Uniqlo merino sweater](https://www.uniqlo.com/us/en/products/E469395-000/00), a [Uniqlo wide straight jeans outfit shot](https://www.uniqlo.com/us/en/products/E470542-000/01), and a [Nike Air Force 1 Low shoe](https://www.nike.com/t/air-force-1-low-mens-shoes-XVPIszaq). They are simulator-only test media; the images are not part of the repository. The outfit shot is useful for checking review of multiple visible garments.

## Camera recognition test service

The Camera and shared-image review screens look for pieces as soon as a new image opens. In Debug they first try a fixture service on this Mac at `127.0.0.1:8765`; if it is unavailable, they fall back to on-device Vision. The service has no paid or live provider mode. Billing is disabled on the separate `dressed-511821` recognition project; the app's `out-fitted` Firebase project is also unbilled. To check the UI, start the fixture service:

```sh
python3 backend/recognition/local_service.py --fixture backend/recognition/fixtures/object-localization-response.json
```

Fixture labels are predetermined and may not match the photo. Only run one service on port 8765 at a time. Confirm it is listening with `lsof -nP -iTCP:8765 -sTCP:LISTEN`; then open a new photo review or tap **Find Pieces Again**. A suggestion should appear unselected. On a physical iPhone, `127.0.0.1` points at the phone, so the Debug bridge will be unavailable and on-device suggestions will run. See [the recognition prototype guide](../backend/recognition/README.md) for limits and troubleshooting.

For a shared image, return to Dressed after finishing the iOS share sheet. The extension cannot force the app to open; Dressed presents the queued review when it becomes active. Recognition begins automatically. The app tries Apple's foreground-instance mask on each suggested crop, then a local edge flood fill for plain product-photo backgrounds. A mask can include skin, miss fabric or retain a shadow, so inspect it before selecting. **Add Piece Manually** opens the region editor. Choose **Draw Outline**, trace with a finger or tap several points and **Close Outline**, then **Use Outline** to replace an inaccurate cutout. A transparent cutout saves as PNG; a rectangle keeps JPEG. Release builds use only on-device suggestions.

On October 16, a real public shoe photo selected from Photos on the iOS 27 simulator opened review and automatically produced one unselected candidate. The background fallback made a 1620×785 transparent PNG; its alpha ranged from 0 to 1 and the shoe was visibly isolated. The simulator's on-device classifier returned an Espresso context error, so the candidate kept the generic name **Piece**. This verifies one plain-background cutout, not general garment segmentation or category accuracy.

## Build, run, inspect, test

From the repository root, substitute your simulator ID for `<UDID>`:

```sh
mobilebuildmcp simulator build-and-run --simulator-id <UDID> --derived-data-path /private/tmp/dressed-mobile-build
mobilebuildmcp simulator open --simulator-id <UDID>
mobilebuildmcp simulator screenshot --simulator-id <UDID>
mobilebuildmcp simulator snapshot-ui --simulator-id <UDID>
mobilebuildmcp simulator test --simulator-id <UDID> --derived-data-path /private/tmp/dressed-mobile-build
```

Use the `ui-automation` tools to tap an element reference from a fresh `snapshot-ui` result. Refresh the snapshot after navigation. Build and test responses include artifact paths for full logs and useful diagnostics. Screenshots show appearance; use accessibility snapshots, interaction, and tests to check behavior. The share flow can require App Group signing and a device; see [project docs](README.md#local-import-prototype).

## Hot reload loop

1. Start `open -a InjectionNext`. For project file watching, use its **…or Watch Project** menu item and select this repository, or use the `watch_project` MCP tool. The Debug scheme sets `INJECTION_PROJECT_ROOT=$(SRCROOT)`, which also lets InjectionNext watch the project when the app connects.
2. Open `dressed.xcodeproj` in the same Xcode selected by `xcode-select`. **Build and run in Xcode once** on the target simulator. File watcher mode reads the Swift frontend commands from an Xcode IDE build log; a standalone `xcodebuild`/MobileBuildMCP build did not supply them in our experiment. You can instead launch Xcode from InjectionNext for supervised mode, then build there.
3. Confirm InjectionNext shows a connected simulator client and a watched project. With the local control server enabled, `printf '%s\n' '{"action":"status"}' | nc -U /tmp/InjectionNext-control.sock` reports `has_connected_client` and `watching_directories`. Use `{"action":"get_logs"}` on the same socket for compiler and injection errors. A connection alone does **not** prove injection worked.
4. Edit the body of an existing SwiftUI view that has `@ObserveInjection` and `.enableInjection()` (currently `Authentication` in `dressed/firebase/AuthPage.swift`). Save; watch for an InjectionNext success message and verify the changed text or layout in a fresh simulator screenshot **without** building, reinstalling, or relaunching. Interact with the affected control when behavior matters. Compare the observed result with the requested behavior and repeat the smallest edit.
5. Do a full rebuild for new or removed files, imports, type/property/signature changes, package or build setting changes, assets, Info.plist, extension or entitlement changes, and any edit that fails injection. Keep Xcode's compilation cache disabled for injection; this project does not explicitly enable it.

`@ObserveInjection` and `.enableInjection()` come from [Inject](https://github.com/krzysztofzablocki/Inject). The app target links [InjectionNext](https://github.com/johnno1962/InjectionNext) and Inject through Swift Package Manager. `EMIT_FRONTEND_COMMAND_LINES=YES` and `-Xlinker -interposable` are set only in the app's Debug configuration. The scheme environment variable applies to Run. Release builds do not get those Debug build settings, and the packages guard injection behavior outside Debug.

## Troubleshooting

- `Could not locate command for ...swift` or `Logs dir not initialised`: build once **in Xcode**, verify `EMIT_FRONTEND_COMMAND_LINES=YES` in Debug, select the watched repository, and retry the source edit. Do not count the earlier failed edit as a successful injection.
- Connected but unchanged screen: inspect `get_logs`, confirm the edited view is visible and uses Inject, confirm the app process stayed alive, then do a full rebuild if necessary. Swift declarations and assets generally require one.
- No simulator interaction: open the Simulator frontend, get a fresh accessibility snapshot, and use the current element reference; duplicate device names require `--simulator-id`.
- Xcode IDE MCP tools may prompt for per-agent project access. Opening the workspace in Xcode alone does not grant that access. Approve it in Xcode if prompted; the MobileBuildMCP CLI simulator workflow works independently.
- If InjectionNext still fails after an IDE build, inspect its logs and current [InjectionNext setup guide](https://github.com/johnno1962/InjectionNext). [InjectionIII](https://github.com/johnno1962/InjectionIII) is the fallback, but stop InjectionNext first so only one injection engine runs. Do not alter the system Swift toolchain to troubleshoot.

## Disable or remove

Quit InjectionNext and run `defaults delete com.johnholdsworth.InjectionNext mcpServer` to disable its control server. Remove its entry from your user-level Codex configuration; remove the MobileBuildMCP entry from `.codex/config.toml` only if the whole team no longer uses it. Remove the injection package references and Debug settings from `dressed.xcodeproj/project.pbxproj`, the Run scheme variable, and the `import Inject`/observation hooks in `AuthPage.swift` to remove hot reload from the project. Optionally uninstall the two local applications and the copied MCP server. MobileBuildMCP can be removed with the package manager used to install it.

## Verification record (2026-10-16)

- macOS 27.0.1, Xcode 27.0, Swift toolchain 6.4; project Swift language version 5.0; iOS target 18.0.
- Debug and Release simulator builds passed on iPhone 16 Pro iOS 18.6 (`B01F45A7-7BB5-41A9-B5AC-B8CB18AE5860`). Debug app launch, screenshot, accessibility snapshot, and tap changing sign in to create account and back passed.
- InjectionNext 2.0.1 was installed from its signed, notarized release. The first controlled title edit failed because it lacked an Xcode IDE compile log. After an IDE build, a second edit compiled in 587 ms and the screenshot showed the changed title without a build, install, or relaunch. The original title returned after a second 313 ms injection. Simulator app PID 43565 stayed running. The temporary text is reverted.
- The first full UI test run passed 2 of 3 cases. `testManualPieceWhenNoSuggestions` failed because its `Piece name` field was below the tappable area when the test tried to type. After the test was adjusted to scroll it into view, the full suite passed: 3 tests, 0 failures.
- The app was relaunched without mock flags, signed in with the test account above, and reached the Camera tab. This separately verifies the real authentication path in the simulator.
- The app also built and launched on the iOS 27.0 iPhone 17 Pro simulator (`FD33AE58-4F68-4424-9D01-5BC234410D90`). Real test-account sign-in succeeded there, and an agent screenshot showed the My Closet screen. This is the newest runtime installed with Xcode 27.0 on this Mac; Apple's latest public iOS patch release at the time was [27.0.1](https://support.apple.com/en-us/100100).

On October 18, an app installed from a `CODE_SIGNING_ALLOWED=NO` build reproduced Firebase Auth's `SecItemCopyMatching (-34018)` startup error on that simulator. The unsigned output identified itself as `dressed` and had no usable signing identity. Rebuilding without that override produced the expected `gtiosclub.dressed` identifier; after installation, Firebase restored the existing test session and the startup Keychain error was absent. This checks session restoration, not a fresh credential submission or a physical-device build.
