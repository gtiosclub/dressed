# SwiftLint

SwiftLint checks Swift source style. The `PR Checks` workflow runs it on pull requests and pushes to the branches listed in [`.github/workflows/pr.yml`](../.github/workflows/pr.yml). The workflow reports violations; it does not edit source or push a fix commit.

## Run it locally

Install SwiftLint with `brew install swiftlint`, then run the same command as CI from the app source directory:

```sh
cd dressed
swiftlint lint
```

Run this from the repository root to check in one command:

```sh
(cd dressed && swiftlint lint)
```

SwiftLint reports the file, line, rule and severity for each finding. Fix the source and rerun the command before marking the PR checklist item complete. For a suggested automatic correction, review the diff after `swiftlint --fix` and run `swiftlint lint` again. Automatic correction changes local files only; commit the reviewed changes yourself.

SwiftLint does not build or exercise the iOS app. For app changes, also run the simulator build in the [root README](../README.md) and exercise affected native UI in a simulator or device.
