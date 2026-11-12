#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/dressed-infinite-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/cache" \
  dressed/Common/Models/ClothingSchema.swift \
  dressed/Common/Models/SocialSchema.swift \
  dressed/Discovery/ViewModels/ChronologicalFeedModel.swift \
  dressed/Discovery/ViewModels/FeedFixtures.swift \
  dressed/Discovery/ViewModels/InfiniteFeedFixtures.swift \
  scripts/tests/InfiniteFeedChecks.swift -o "$check_dir/check"
"$check_dir/check"
