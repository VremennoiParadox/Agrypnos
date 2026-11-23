#!/usr/bin/env bash
# Build Agrypnos.app on macOS. Requires Xcode or Command Line Tools with xcodebuild.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-macos.sh must run on a Mac. On Linux use ./Scripts/verify-linux.sh" >&2
  exit 1
fi

DEST="${ROOT}/dist"
mkdir -p "$DEST"

xcodebuild \
  -project "$ROOT/Apps/Agrypnos/Agrypnos.xcodeproj" \
  -scheme Agrypnos \
  -configuration Release \
  -derivedDataPath "$ROOT/.derivedData" \
  CODE_SIGN_IDENTITY="-" \
  build

APP=$(find "$ROOT/.derivedData" -name "Agrypnos.app" -type d | head -n 1)
if [ -z "$APP" ]; then
  echo "xcodebuild finished but Agrypnos.app was not found." >&2
  exit 1
fi
# The grant installer and OpenCode setup load these at runtime. A regenerated project once dropped one.
for resource in grant.sh agrypnos-opencode.js AppIcon.icns; do
  if [ ! -f "$APP/Contents/Resources/$resource" ]; then
    echo "Built app is missing Resources/$resource. Run Scripts/generate-xcodeproj.py and check its resource list." >&2
    exit 1
  fi
done
rm -rf "$DEST/Agrypnos.app"
cp -R "$APP" "$DEST/Agrypnos.app"
echo "Built $DEST/Agrypnos.app"
echo "Then: open $DEST/Agrypnos.app"
echo "First toggle may ask for the one-time pmset grant."
