#!/usr/bin/env bash
# Builds a Release archive of Wingmate and packages it as zip + dmg in dist/.
#
# Signing (personal use, no Apple account):
#   SIGNING_IDENTITY  name of a code signing identity, e.g. "Wingmate Self-Signed".
#                     A stable identity keeps macOS privacy permissions (Calendar,
#                     Accessibility) across updates. Without it the build is ad-hoc
#                     signed and permissions must be granted again after each update.
#   SIGNING_KEYCHAIN  optional keychain that holds the identity.
set -euo pipefail

VERSION="${VERSION:-$(grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHIVE="build/Wingmate.xcarchive"
DIST="dist"

rm -rf "$ARCHIVE" "$DIST"
mkdir -p "$DIST"

[ -d Wingmate.xcodeproj ] || xcodegen generate

xcodebuild archive \
  -project Wingmate.xcodeproj \
  -scheme Wingmate \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=

APP="$ARCHIVE/Products/Applications/Wingmate.app"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  echo "==> Signing with \"$SIGNING_IDENTITY\""
  codesign --force --deep --options runtime \
    --entitlements Wingmate/Resources/Wingmate.entitlements \
    --sign "$SIGNING_IDENTITY" \
    ${SIGNING_KEYCHAIN:+--keychain "$SIGNING_KEYCHAIN"} \
    "$APP"
  codesign -d -r- "$APP" 2>&1 | grep -q 'certificate leaf' \
    || { echo "error: designated requirement is not bound to the certificate"; exit 1; }
else
  echo "warning: SIGNING_IDENTITY not set, build is ad-hoc signed (permissions reset on update)"
fi

codesign --verify --deep --strict "$APP"
codesign -d -r- "$APP" 2>&1 | tail -1

ditto -c -k --keepParent "$APP" "$DIST/Wingmate-$VERSION.zip"
hdiutil create -volname "Wingmate" -srcfolder "$APP" -ov -format UDZO "$DIST/Wingmate-$VERSION.dmg"

# The Homebrew cask downloads the latest release under a fixed name.
cp "$DIST/Wingmate-$VERSION.dmg" "$DIST/Wingmate.dmg"

(cd "$DIST" && shasum -a 256 ./* > SHA256SUMS.txt)
echo "==> Artifacts:"; ls -lh "$DIST"
