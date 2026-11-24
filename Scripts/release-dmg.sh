#!/usr/bin/env bash
# Build dist/Agrypnos.dmg: Developer ID signed, notarized, and stapled.
# Needs a "Developer ID Application" certificate in the keychain and a saved notarytool profile:
#   xcrun notarytool store-credentials agrypnos-notary --apple-id <apple id> --team-id <team id>
set -euo pipefail
cd "$(dirname "$0")/.."
PROFILE="${NOTARY_PROFILE:-agrypnos-notary}"
IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -n 1)
if [ -z "$IDENTITY" ]; then
  echo "No Developer ID Application certificate in the keychain." >&2
  exit 1
fi

./Scripts/build-macos.sh
APP=dist/Agrypnos.app
DMG=dist/Agrypnos.dmg

# MIT asks for the notice in every copy.
cp LICENSE "$APP/Contents/Resources/LICENSE"
# Notarization needs the hardened runtime, a secure timestamp, and no debug entitlement.
codesign --force --options runtime --timestamp \
  --entitlements Apps/Agrypnos/Resources/Agrypnos.entitlements --sign "$IDENTITY" "$APP"

# Staple the app itself, so the copy in Applications also opens offline.
ditto -c -k --keepParent "$APP" dist/Agrypnos.zip
xcrun notarytool submit dist/Agrypnos.zip --keychain-profile "$PROFILE" --wait
rm dist/Agrypnos.zip
xcrun stapler staple "$APP"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname Agrypnos -srcfolder "$STAGE" -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --sign "$IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

spctl -a -vv "$APP"
spctl -a -t open --context context:primary-signature -vv "$DMG"
echo "Version $(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)"
shasum -a 256 "$DMG"
