# SwiftLint guide

SwiftLint checks the style of Swift source files. Run it before opening a pull request; the [PR Checks workflow](../.github/workflows/pr.yml) runs the same check in CI. Linting does not build or exercise the iOS app.

## Install and run

On macOS, install SwiftLint with Homebrew:

```sh
brew install swiftlint
swiftlint version
```

From the repository root, run the same command and working directory used by CI:

```sh
(cd dressed && swiftlint lint)
```

You can also enter the `dressed/` directory and run `swiftlint lint` there. A clean run exits successfully. Findings identify the file, line, rule, and severity; an error makes the CI lint job fail. SwiftLint is not currently installed by the Xcode project, so an Xcode build alone does not run this check.

## Fix findings

1. Open the reported file and fix the finding. Keep behavior changes separate from style cleanup when possible.
2. Rerun `(cd dressed && swiftlint lint)`.
3. Review `git diff --check` and `git diff` before committing.

For rules with automatic corrections, run `swiftlint --fix` from `dressed/`, inspect its diff, and rerun `swiftlint lint`. Auto-fix edits local files; it does not commit or push them. If a rule conflicts with an intentional code pattern, discuss a narrow configuration change in the pull request rather than silently disabling lint for the whole project.

## What CI checks

The [workflow](../.github/workflows/pr.yml) installs SwiftLint on a macOS runner and runs `swiftlint lint` from `dressed/`. Its current branch filters name `main`, `ingestion_main`, `social_main`, and `visualization_main`; a direct push to `data_main` or `viz_main` does not match those push filters. Pull requests targeting `main` do run the check. CI reports findings and never edits or pushes source files.

The repository has no merge ruleset, so a failing check does not itself prevent a merge or direct push. The [pull request checklist](../.github/pull_request_template.md) asks contributors to confirm SwiftLint passes. For app changes, also run the [simulator build](../README.md#command-line-build) and exercise affected native UI in a simulator or device.
