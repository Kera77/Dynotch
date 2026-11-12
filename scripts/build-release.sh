#!/usr/bin/env bash
# Builds a Release archive of Dynotch (ad-hoc signed, personal use) and packages
# it as zip + dmg in dist/.
set -euo pipefail

VERSION="${VERSION:-$(grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHIVE="build/Dynotch.xcarchive"
DIST="dist"

rm -rf "$ARCHIVE" "$DIST"
mkdir -p "$DIST"

[ -d Dynotch.xcodeproj ] || xcodegen generate

xcodebuild archive \
  -project Dynotch.xcodeproj \
  -scheme Dynotch \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=

APP="$ARCHIVE/Products/Applications/Dynotch.app"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$DIST/Dynotch-$VERSION.zip"
hdiutil create -volname "Dynotch" -srcfolder "$APP" -ov -format UDZO "$DIST/Dynotch-$VERSION.dmg"

(cd "$DIST" && shasum -a 256 ./* > SHA256SUMS.txt)
echo "==> Artifacts:"; ls -lh "$DIST"
