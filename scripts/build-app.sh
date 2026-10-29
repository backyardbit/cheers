#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
APP="build/Cheers.app"
IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]] && security find-identity -p codesigning 2>/dev/null | grep -q "Cheers Local Signing"; then
    IDENTITY="Cheers Local Signing"
fi

swift build -c "$CONFIGURATION" --product Cheers
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/Cheers" "$APP/Contents/MacOS/Cheers"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

shopt -s nullglob
for bundle in "$BIN_PATH"/*.bundle; do
    cp -R "$bundle" "$APP/Contents/Resources/"
done

SIGN_ARGS=(--force --sign "${IDENTITY:--}" --identifier com.benkleyner.cheers)
if [[ "$IDENTITY" == Developer\ ID\ Application* ]]; then
    SIGN_ARGS+=(--options runtime --timestamp --entitlements Resources/Cheers.entitlements)
fi
codesign "${SIGN_ARGS[@]}" "$APP"
echo "Built $APP (signed with ${IDENTITY:-ad-hoc identity})"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Cheers || true
    rm -rf /Applications/Cheers.app
    cp -R "$APP" /Applications/Cheers.app
    open /Applications/Cheers.app
    echo "Installed to /Applications/Cheers.app"
fi
