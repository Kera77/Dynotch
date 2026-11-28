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
# The rename bridge under the old name, for updaters up to 1.9.1 (spec RN-9).
BRIDGE="$ARCHIVE/Products/Applications/Dynotch.app"

sign() { # app, identifier, entitlements (optional)
  if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    echo "==> Signing $(basename "$1") with \"$SIGNING_IDENTITY\""
    codesign --force --deep --options runtime \
      ${3:+--entitlements "$3"} \
      --sign "$SIGNING_IDENTITY" \
      ${SIGNING_KEYCHAIN:+--keychain "$SIGNING_KEYCHAIN"} \
      "$1"
    codesign -d -r- "$1" 2>&1 | grep -q 'certificate leaf' \
      || { echo "error: designated requirement is not bound to the certificate"; exit 1; }
    # The updaters check the identifier in the requirement (spec U-2, U-11).
    codesign -d -r- "$1" 2>&1 | grep -q "identifier \"$2\"" \
      || { echo "error: $(basename "$1") is not signed as $2"; exit 1; }
  fi
  codesign --verify --deep --strict "$1"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$1/Contents/Info.plist")" == "$2" ]] \
    || { echo "error: $(basename "$1") is not $2"; exit 1; }
  codesign -d -r- "$1" 2>&1 | tail -1
}

[[ -n "${SIGNING_IDENTITY:-}" ]] \
  || echo "warning: SIGNING_IDENTITY not set, build is ad-hoc signed (permissions reset on update)"
sign "$APP" com.peterkereki.Wingmate Wingmate/Resources/Wingmate.entitlements
sign "$BRIDGE" com.peterkereki.Dynotch
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$BRIDGE/Contents/Info.plist")" == "$VERSION" ]] \
  || { echo "error: the bridge is not version $VERSION"; exit 1; }

ditto -c -k --keepParent "$APP" "$DIST/Wingmate-$VERSION.zip"
ditto -c -k --keepParent "$BRIDGE" "$DIST/Dynotch-$VERSION.zip"
hdiutil create -volname "Wingmate" -srcfolder "$APP" -ov -format UDZO "$DIST/Wingmate-$VERSION.dmg"

# The Homebrew cask downloads the latest release under a fixed name.
cp "$DIST/Wingmate-$VERSION.dmg" "$DIST/Wingmate.dmg"

(cd "$DIST" && shasum -a 256 ./* > SHA256SUMS.txt)
echo "==> Artifacts:"; ls -lh "$DIST"
