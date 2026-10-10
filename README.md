# dressed
GT iOS Club Fall 2026 - Dressed app

Native SwiftUI app for iPhone and iPad, using Firebase and Swift Package Manager.

## Run locally

1. Open `dressed.xcodeproj` in Xcode (local setup uses Xcode 26.6).
2. Allow Xcode to resolve the Firebase Swift packages.
3. Select the `dressed` scheme and an iOS 18.0 or newer simulator.
4. Press **Command-R** to build and run.

The deployment target is iOS 18.0. Use an iOS 18.0 or newer simulator or device.

## Firebase

The existing `dressed/GoogleService-Info.plist` matches the app bundle identifier, `gtiosclub.dressed`. Firebase is initialized in `DressedApp.swift`.

Email/password sign-in and account creation require the Email/Password provider to be enabled in the matching Firebase project's Authentication settings. Local compilation does not verify that server-side setting. Successful authentication currently prints a message; the app does not yet navigate to another screen.

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

Keep the workspace's shared `Package.resolved` file in version control to preserve resolved dependency versions. Ignore generated build files and per-user Xcode settings using the included `.gitignore`.

## Project scope and subteams

Start with [project docs](docs/README.md), [team ownership](docs/teams.md), and the [GitHub backlog](docs/github-issues.md). Work is split between `viz`, `data`, and `social`. Shared schema templates live in [dressed/Common/Models](dressed/Common/Models), following SideQuest's shared-code / feature-folder pattern. [Backend examples](backend/schemas/README.md) document the proposed storage contracts. These types do not implement or deploy backend services. Coding agents should read [AGENTS.md](AGENTS.md).
