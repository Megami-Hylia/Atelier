#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ "$(uname -s)" == Darwin ]] || { echo 'Requires macOS and Xcode.'; exit 1; }
: "${ATELIER_TEAM_ID:?Set your Apple development team ID}"
: "${ATELIER_BUNDLE_ID:?Set a bundle identifier registered to your team}"
: "${ATELIER_EXPORT_OPTIONS:?Set the absolute path of ExportOptions.plist exported by Xcode}"
test -f "$ATELIER_EXPORT_OPTIONS"
OUT="$ROOT/build/signed"
test ! -e "$OUT" || { echo 'build/signed already exists; choose a fresh project copy.'; exit 1; }
mkdir -p "$OUT"
python3 scripts/source_identity.py --output "$OUT/source-identity.json"
xcodebuild -project Atelier.xcodeproj -scheme Atelier -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Atelier.xcarchive" \
  -derivedDataPath "$ROOT/build/DerivedData-signed" -allowProvisioningUpdates \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development' DEVELOPMENT_TEAM="$ATELIER_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$ATELIER_BUNDLE_ID" archive 2>&1 | tee "$OUT/archive.log"
xcodebuild -exportArchive -archivePath "$OUT/Atelier.xcarchive" \
  -exportOptionsPlist "$ATELIER_EXPORT_OPTIONS" -exportPath "$OUT/export" \
  -allowProvisioningUpdates 2>&1 | tee "$OUT/export.log"
echo "Archive and export finished: $OUT"
