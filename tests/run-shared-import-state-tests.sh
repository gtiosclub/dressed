#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/dressed-state-tests.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -module-cache-path "$test_directory/cache" \
    dressed/Common/Models/ClothingSchema.swift \
    dressed/Common/Models/ImportSchema.swift \
    dressed/Camera/ViewModels/SharedImportReviewState.swift \
    tests/SharedImportReviewStateTests.swift -o "$test_directory/tests"
"$test_directory/tests"
