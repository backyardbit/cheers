#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Cheers-$VERSION.dmg"
STAGING="build/dmg"

./scripts/build-app.sh

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/Cheers.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Cheers" -srcfolder "$STAGING" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG"
rm -rf "$STAGING"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$CODESIGN_IDENTITY" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

shasum -a 256 "$DMG"
echo "Created $DMG"
