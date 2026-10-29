#!/bin/bash
set -euo pipefail

# Invoke with bash; Windows source ZIPs do not need POSIX executable bits.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build/delivery"
STAGING="$ROOT/build/ipa-staging"
DERIVED="$ROOT/build/DerivedData-device"
mkdir -p "$OUT" "$STAGING/Payload"
exec > >(tee "$OUT/build.log") 2>&1

if [[ "$(uname -s)" != Darwin ]]; then
  echo "ERROR: Native Swift/UIKit/Metal compilation requires macOS and Xcode, not Windows."
  exit 1
fi
: "${DEVELOPER_DIR:=/Applications/Xcode_26.2.app/Contents/Developer}"
export DEVELOPER_DIR
test -d "$DEVELOPER_DIR" || { echo "ERROR: Pinned Xcode 26.2 is unavailable: $DEVELOPER_DIR"; exit 1; }
xcodebuild -version | tee "$OUT/xcode-version.txt"
grep -qx 'Xcode 26.2' "$OUT/xcode-version.txt"
grep -qx 'Build version 17C52' "$OUT/xcode-version.txt"
xcrun --sdk iphoneos --show-sdk-version | tee "$OUT/sdk-version.txt"
grep -qx '26.2' "$OUT/sdk-version.txt"
sw_vers > "$OUT/macos-version.txt"
xcrun swift --version > "$OUT/swift-version.txt"
if ! xcrun --sdk iphoneos metal -v > "$OUT/metal-version.txt" 2>&1; then
  cat "$OUT/metal-version.txt"
  echo 'Installing the official Metal Toolchain component for the selected Xcode.'
  xcodebuild -downloadComponent MetalToolchain
  xcrun --sdk iphoneos metal -v > "$OUT/metal-version.txt" 2>&1
fi
cat "$OUT/metal-version.txt"

BUILD_ARGS=(-jobs 1 -project Atelier.xcodeproj -scheme Atelier -configuration Release
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED"
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO TARGETED_DEVICE_FAMILY=2 SWIFT_MAXIMUM_CONCURRENT_COMPILE_TASKS=1
  SUPPORTS_MACCATALYST=NO SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 'CODE_SIGN_IDENTITY='
  'DEVELOPMENT_TEAM=' 'PROVISIONING_PROFILE_SPECIFIER=')

# No external packages or Pods: there are no dependency downloads to resolve.
xcodebuild "${BUILD_ARGS[@]}" -showBuildSettings -json > "$OUT/effective-build-settings.json"
python3 - "$OUT/effective-build-settings.json" <<'PY'
import json, sys
targets = json.load(open(sys.argv[1]))
assert targets, 'No targets returned by xcodebuild'
expected = {'CODE_SIGNING_ALLOWED':'NO', 'CODE_SIGNING_REQUIRED':'NO',
            'CODE_SIGN_IDENTITY':'', 'TARGETED_DEVICE_FAMILY':'2',
            'PLATFORM_NAME':'iphoneos', 'SUPPORTS_MACCATALYST':'NO'}
for target in targets:
    settings = target['buildSettings']
    for key, value in expected.items():
        # Xcode omits explicitly empty settings from its JSON representation.
        actual = settings.get(key, '' if value == '' else None)
        assert actual == value, (target['target'], key, actual)
    assert settings.get('ARCHS') == 'arm64', settings.get('ARCHS')
PY
xcodebuild "${BUILD_ARGS[@]}" build

APP="$DERIVED/Build/Products/Release-iphoneos/Atelier.app"
test -f "$APP/Atelier" || { echo 'ERROR: Device app executable missing.'; exit 1; }
test -f "$APP/default.metallib" || { echo 'ERROR: Compiled Metal shaders missing.'; exit 1; }
file "$APP/Atelier" | tee "$OUT/executable-file.txt"
xcrun vtool -show-build "$APP/Atelier" | tee "$OUT/executable-platform.txt"
/usr/bin/codesign -dvv "$APP" > "$OUT/codesign-inspection.txt" 2>&1 && {
  echo 'ERROR: App unexpectedly has a code signature.'; exit 1;
}

# A fresh job normally has no previous staging. Refuse to replace stale content.
test ! -e "$STAGING/Payload/Atelier.app" || { echo 'ERROR: Stale staging; use a clean checkout/build folder.'; exit 1; }
ditto "$APP" "$STAGING/Payload/Atelier.app"
IPA="$OUT/Atelier-unsigned.ipa"
test ! -e "$IPA" || { echo 'ERROR: IPA already exists; use a clean build folder.'; exit 1; }
(cd "$STAGING" && /usr/bin/zip -q -r -y "$IPA" Payload)
python3 scripts/verify_ipa.py "$IPA" --report "$OUT/ipa-verification.json"
shasum -a 256 "$IPA" > "$OUT/SHA256SUMS.txt"

python3 - "$OUT" <<'PY'
import datetime, json, os, pathlib, subprocess, sys
out = pathlib.Path(sys.argv[1])
def read(name): return (out / name).read_text().strip()
commit = os.environ.get('GITHUB_SHA') or subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
report = {'status':'BUILT_AND_STRUCTURALLY_VERIFIED', 'commit':commit,
 'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'runner':os.environ.get('RUNNER_OS'), 'runner_arch':os.environ.get('RUNNER_ARCH'),
 'runner_image':os.environ.get('ImageOS'), 'runner_image_version':os.environ.get('ImageVersion'),
 'workflow_run_url':f"{os.environ.get('GITHUB_SERVER_URL','https://github.com')}/{os.environ.get('GITHUB_REPOSITORY','')}/actions/runs/{os.environ.get('GITHUB_RUN_ID','')}",
 'xcode':read('xcode-version.txt'), 'sdk':read('sdk-version.txt'), 'macos':read('macos-version.txt'),
 'swift':read('swift-version.txt'), 'metal':read('metal-version.txt'), 'ipa':json.loads(read('ipa-verification.json')),
 'signing':'disabled; no Apple secrets used', 'hardware_tests':'not executed by this script',
 'simulator_tests':'separate CI step; see test log/xcresult', 'parity':'not demonstrated by build'}
(out/'BUILD_REPORT.json').write_text(json.dumps(report,indent=2)+'\n')
PY
echo "SUCCESS: $IPA"
