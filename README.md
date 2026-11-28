# dressed
GT iOS Club Fall 2026 - Dressed app

Native SwiftUI app for iPhone and iPad, using Firebase and Swift Package Manager.

## Run locally

1. Open `dressed.xcodeproj` in Xcode.
2. Allow Xcode to resolve the Firebase Swift packages.
3. Select the `dressed` scheme and an iOS 18.0 or newer simulator.
4. Press **Command-R** to build and run.

The deployment target is iOS 18.0. Use an iOS 18.0 or newer simulator or device.

## Firebase

The existing `dressed/GoogleService-Info.plist` matches the app bundle identifier, `gtiosclub.dressed`. Firebase is initialized in `DressedApp.swift`.

The tracked plist is public Firebase client configuration, not an administrator credential. The app uses the unbilled `out-fitted` project for email/password sign-in and gated backend features. Normal sign-in requires an account in that project; the Debug UI tests use a mock session. Closet and Wishlist prototype data are stored on the device. Firebase rules and project permissions still control shared backend access; cloning the repo does not grant cloud administration.

The separate `dressed-511821` recognition project has billing and Vision enabled for bounded development testing. The Debug simulator app can call a developer-run local bridge for live Object Localization after that developer signs in with Google Cloud CLI and receives project access. Fixture and on-device recognition still work without Google access. The Product Search CLI reads saved responses only and does not identify live products. The offline eBay adapter needs a saved response file; it has no live API connection. See [recognition setup](backend/recognition/README.md) and [catalog setup](backend/catalog/README.md).

To use a different Firebase project, register an iOS app with the matching bundle identifier and replace the configuration plist with that project's downloaded file.

## Command-line build

From this directory:

```sh
xcodebuild -project dressed.xcodeproj \
  -scheme dressed \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/dressed-setup-build \
  CODE_SIGNING_ALLOWED=NO build
```

For a physical iPhone or iPad, select your development team under **Signing & Capabilities** in Xcode. Simulator builds do not require a signing account.

The Share Extension's App Group needs both targets signed with an Apple team that has the `group.gtiosclub.dressed` entitlement. Contributors without that entitlement can still run the simulator app's photo-library, manual review, local closet, Wishlist, and fixture-backed tests. Optional MobileBuildMCP setup is in [iOS development](docs/IOS_DEVELOPMENT.md); its tracked Codex command uses the contributor's `PATH`.

Keep the workspace's shared `Package.resolved` file in version control to preserve resolved dependency versions. Ignore generated build files and per-user Xcode settings using the included `.gitignore`.

## Linting

See the [SwiftLint guide](docs/linting.md) for installation, the exact local command, how CI runs it, and how to review automatic fixes.

## Project scope and subteams

Start with [project docs](docs/README.md), [team ownership](docs/teams.md), and the [GitHub backlog](docs/github-issues.md). Work is split between `viz`, `data`, and `social`. Shared schema templates live in [dressed/Common/Models](dressed/Common/Models), following SideQuest's shared-code / feature-folder pattern. [Backend examples](backend/schemas/README.md) document the proposed storage contracts. These types do not implement or deploy backend services. Coding agents should read [AGENTS.md](AGENTS.md).
