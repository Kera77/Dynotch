#!/usr/bin/env bash
# Builds a Release archive of Dynotch and packages it as a zip (+ dmg) in dist/.
# Signing/notarization happen only when the related env vars are set:
#   DEVELOPER_ID_APPLICATION  e.g. "Developer ID Application: Name (TEAMID)"
#   DEVELOPMENT_TEAM          Apple Team ID
#   APPLE_ID, APPLE_APP_PASSWORD  (app-specific password) -> notarization
set -euo pipefail

VERSION="${VERSION:-$(grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHIVE="build/Dynotch.xcarchive"
DIST="dist"

rm -rf "$ARCHIVE" "$DIST"
mkdir -p "$DIST"

[ -d Dynotch.xcodeproj ] || xcodegen generate

SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGN_ARGS=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=${DEVELOPER_ID_APPLICATION}"
    "DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM required for signing}"
    OTHER_CODE_SIGN_FLAGS=--timestamp
  )
fi

xcodebuild archive \
  -project Dynotch.xcodeproj \
  -scheme Dynotch \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${SIGN_ARGS[@]}"

APP="$ARCHIVE/Products/Applications/Dynotch.app"
ZIP="$DIST/Dynotch-$VERSION.zip"
DMG="$DIST/Dynotch-$VERSION.dmg"

ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "==> Notarizing app"
  xcrun notarytool submit "$ZIP" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
    --team-id "$DEVELOPMENT_TEAM" --wait
  xcrun stapler staple "$APP"
  rm "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
fi

hdiutil create -volname "Dynotch" -srcfolder "$APP" -ov -format UDZO "$DMG"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG"
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "==> Notarizing dmg"
    xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
      --team-id "$DEVELOPMENT_TEAM" --wait
    xcrun stapler staple "$DMG"
  fi
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "==> Verifying Gatekeeper acceptance"
  spctl --assess --type execute -vv "$APP"
  xcrun stapler validate "$APP"
  xcrun stapler validate "$DMG"
else
  echo "warning: build is NOT signed/notarized (signing secrets not configured)"
fi

(cd "$DIST" && shasum -a 256 ./* > SHA256SUMS.txt)
echo "==> Artifacts:"; ls -lh "$DIST"
