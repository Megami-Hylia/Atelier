#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build/tests
exec > >(tee build/tests/test.log) 2>&1
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode_26.2.app/Contents/Developer}"
SIM_ARCH="$(uname -m)"
DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime, entries in devices.items():
    if runtime.endswith("iOS-26-2"):
        for entry in entries:
            if entry.get("isAvailable") and entry["name"].startswith("iPad"):
                print(entry["udid"]); sys.exit(0)
sys.exit("No available iPad iOS 26.2 simulator: simulator tests not executed")
')"
set +e
xcodebuild -project Atelier.xcodeproj -scheme Atelier -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData-tests -resultBundlePath build/tests/AtelierTests.xcresult \
  ARCHS="$SIM_ARCH" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= test
TEST_STATUS=$?
set -e
if [[ -d build/tests/AtelierTests.xcresult ]]; then
  xcrun xcresulttool export attachments --path build/tests/AtelierTests.xcresult \
    --output-path build/tests/attachments || echo 'WARNING: attachment export failed; inspect xcresult directly.'
fi
exit "$TEST_STATUS"
