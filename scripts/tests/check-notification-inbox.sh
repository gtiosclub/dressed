#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/dressed-notification-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/cache" \
  dressed/Common/Models/ClothingSchema.swift \
  dressed/Common/Models/SocialSchema.swift \
  dressed/Common/Models/DiscoverySchema.swift \
  dressed/Discovery/ViewModels/NotificationInboxModel.swift \
  dressed/Discovery/ViewModels/NotificationFixtures.swift \
  scripts/tests/NotificationInboxChecks.swift -o "$check_dir/check"
"$check_dir/check"
