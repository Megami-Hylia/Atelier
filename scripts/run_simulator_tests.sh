#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build/tests
exec > >(tee build/tests/test.log) 2>&1
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode_26.2.app/Contents/Developer}"
SIM_ARCH="$(uname -m)"
xcodebuild -runFirstLaunch
xcrun simctl list runtimes > build/tests/simulator-runtimes.txt
DEVICE_ID="$(python3 <<'PY'
import json, os, pathlib, subprocess, sys, uuid
def inventory(kind):
    return json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', kind, '--json'], text=True))[kind]
runtimes = [r for r in inventory('runtimes') if r['identifier'].endswith('iOS-26-2') and r.get('isAvailable')]
types = [t for t in inventory('devicetypes') if t['name'] == 'iPad (A16)']
if not runtimes or not types:
    sys.exit('Required available iOS 26.2 runtime or iPad (A16) device type absent; tests not executed')
name = f"AtelierCI-{os.environ.get('GITHUB_RUN_ID', 'manual')}-{uuid.uuid4().hex[:8]}"
device = subprocess.check_output(['xcrun', 'simctl', 'create', name, types[0]['identifier'], runtimes[0]['identifier']], text=True).strip()
uuid.UUID(device)
pathlib.Path('build/tests/simulator-created.json').write_text(json.dumps({
    'udid':device, 'name':name, 'type':types[0]['identifier'], 'runtime':runtimes[0]['identifier'],
    'ownership':'created by this script; only this UUID may be removed'
}, indent=2) + '\n')
print(device)
PY
)"
readonly DEVICE_ID
cleanup_created_simulator() {
  local test_exit=$?
  # DEVICE_ID comes exclusively from this script's successful simctl create.
  xcrun simctl shutdown "$DEVICE_ID" >/dev/null 2>&1 || true
  xcrun simctl delete "$DEVICE_ID" >/dev/null 2>&1 || true
  return "$test_exit"
}
trap cleanup_created_simulator EXIT
python3 - "$DEVICE_ID" <<'PY'
import datetime, json, pathlib, subprocess, sys
device = sys.argv[1]
report = {'udid':device, 'timeout_seconds':300, 'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
try:
    result = subprocess.run(['xcrun', 'simctl', 'bootstatus', device, '-b'], timeout=300)
    report['status'] = 'booted' if result.returncode == 0 else 'failed'
    status = result.returncode
except subprocess.TimeoutExpired:
    report['status'] = 'timed_out'
    status = 124
    print('ERROR: fresh iPad simulator boot exceeded 300 seconds; no XCTest executed.', file=sys.stderr)
report['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
pathlib.Path('build/tests/simulator-boot.json').write_text(json.dumps(report, indent=2) + '\n')
with open('build/tests/simulator-inventory.json', 'w') as output:
    subprocess.run(['xcrun', 'simctl', 'list', '--json'], stdout=output, stderr=subprocess.STDOUT)
if status:
    pathlib.Path('build/tests/test-summary.json').write_text(json.dumps({'available':False, 'reason':'Simulator boot failed or timed out; no XCTest executed'}) + '\n')
sys.exit(status)
PY
xcodebuild -project Atelier.xcodeproj -scheme Atelier -configuration Debug \
  -sdk iphonesimulator ARCHS="$SIM_ARCH" -showdestinations > build/tests/simulator-destinations.txt
cat build/tests/simulator-destinations.txt
set +e
xcodebuild -project Atelier.xcodeproj -scheme Atelier -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DEVICE_ID" -destination-timeout 120 \
  -derivedDataPath build/DerivedData-tests -resultBundlePath build/tests/AtelierTests.xcresult \
  ARCHS="$SIM_ARCH" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= test
TEST_STATUS=$?
set -e
if [[ -d build/tests/AtelierTests.xcresult ]]; then
  if ! xcrun xcresulttool get test-results summary --path build/tests/AtelierTests.xcresult \
    > build/tests/test-summary.json; then
    echo 'WARNING: machine test summary unavailable; inspect test.log and xcresult directly.'
    printf '%s\n' '{"available":false,"reason":"xcresulttool summary failed; see test.log"}' > build/tests/test-summary.json
  fi
  xcrun xcresulttool export attachments --path build/tests/AtelierTests.xcresult \
    --output-path build/tests/attachments || echo 'WARNING: attachment export failed; inspect xcresult directly.'
fi
exit "$TEST_STATUS"
