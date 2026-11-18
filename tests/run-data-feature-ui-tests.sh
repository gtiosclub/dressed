#!/usr/bin/env bash
set -euo pipefail

# Run the merged Data feature flows on a dedicated iOS simulator. The UI tests
# use a mock session to isolate import behavior; this does not test Firebase login.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
simulator_id="${SIMULATOR_ID:?Set SIMULATOR_ID to a disposable iOS simulator UDID}"
derived_data_path="${DRESSED_DATA_TEST_BUILD:-/private/tmp/dressed-data-ui-tests}"
fixture_dir="$(mktemp -d)"
run_dir="$(mktemp -d /private/tmp/dressed-data-ui-run.XXXXXX)"
trap 'rm -rf "$fixture_dir"' EXIT

# Erase only the simulator made for this suite. A fresh Photos library and app
# container prevent pending import drafts from affecting later test cases.
simulator_name="$(xcrun simctl list devices --json | python3 -c '
import json, sys
identifier = sys.argv[1]
for runtime_devices in json.load(sys.stdin)["devices"].values():
    for device in runtime_devices:
        if device["udid"] == identifier:
            print(device["name"])
            sys.exit(0)
sys.exit(1)
' "$simulator_id")"
if [[ "$simulator_name" != "Dressed Data E2E" ]]; then
  echo "Refusing to erase '$simulator_name'; use a simulator named Dressed Data E2E." >&2
  exit 1
fi
xcrun simctl shutdown "$simulator_id" 2>/dev/null || true
xcrun simctl erase "$simulator_id"

# PhotosPicker needs real library assets even when recognition uses fixture or
# simulator fallbacks. Distinct synthetic images exercise selection, not model
# accuracy. Leave these on the dedicated test simulator for repeat runs.
python3 - "$fixture_dir" <<'PY'
import pathlib
import struct
import sys
import zlib

target = pathlib.Path(sys.argv[1])


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


for name, color in (("blue", (30, 90, 220)), ("red", (220, 70, 60))):
    width = height = 128
    row = b"\x00" + bytes(color) * width
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(row * height))
    png += chunk(b"IEND", b"")
    (target / f"data-picker-{name}.png").write_bytes(png)
PY

xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl addmedia "$simulator_id" \
  "$fixture_dir/data-picker-blue.png" "$fixture_dir/data-picker-red.png"

cd "$repo_root"
set +e
xcodebuild \
  -project dressed.xcodeproj \
  -scheme dressed \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$run_dir/Test.xcresult" \
  -parallel-testing-enabled NO \
  -only-testing:dressedUITests/NavigationUITests/testPhotoLibraryImportModeAndPickerEntry \
  -only-testing:dressedUITests/NavigationUITests/testSelectingMultiplePhotosOpensCombinedReview \
  -only-testing:dressedUITests/NavigationUITests/testFullOutfitMultiPhotoReviewStartsUnselected \
  -only-testing:dressedUITests/ShareImportUITests/testManualPieceWhenNoSuggestions \
  -only-testing:dressedUITests/ShareImportUITests/testApproveSkipThenChangeSelection \
  -only-testing:dressedUITests/ShareImportUITests/testReviewSelectTwoSkipOneSaveOutfitAndReopen \
  -only-testing:dressedUITests/ShareImportUITests/testLaterRestoresProgressAndIndividualImport \
  -only-testing:dressedUITests/ShareImportUITests/testReviewProductURLAndKeepWishlistAfterRelaunch \
  test
test_status=$?
set -e

xcrun xcresulttool export attachments \
  --path "$run_dir/Test.xcresult" \
  --output-path "$run_dir/screenshots"
echo "Test result: $run_dir/Test.xcresult"
echo "Screenshots: $run_dir/screenshots"
exit "$test_status"
