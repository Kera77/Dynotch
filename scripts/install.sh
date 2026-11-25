#!/usr/bin/env bash
# Downloads a Dynotch release from GitHub and installs it to /Applications.
# Usage: ./scripts/install.sh [vX.Y.Z]   (default: latest; an older version turns automatic updates off)
set -euo pipefail

TAG="${1:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh release download $TAG -R Kera77/Dynotch -p 'Dynotch-*.zip' -p 'SHA256SUMS.txt' -D "$TMP"
(cd "$TMP" && shasum -a 256 -c SHA256SUMS.txt --ignore-missing)

ditto -x -k "$TMP"/Dynotch-*.zip "$TMP/app"
osascript -e 'quit app "Dynotch"' 2>/dev/null || true
rm -rf /Applications/Dynotch.app
ditto "$TMP/app/Dynotch.app" /Applications/Dynotch.app
xattr -dr com.apple.quarantine /Applications/Dynotch.app 2>/dev/null || true

# An older version than the newest (going back by hand, spec RF-21): no automatic update, or the app
# would update itself again within a minute. Turn it back on in Settings › About.
if [[ -n "$TAG" && "$TAG" != "$(gh release view -R Kera77/Dynotch --json tagName -q .tagName)" ]]; then
  defaults write com.peterkereki.Dynotch updatesManual -bool true
  echo "Automatic updates turned off (Settings › About to turn them on again)."
fi
open /Applications/Dynotch.app
echo "Installed $(plutil -extract CFBundleShortVersionString raw /Applications/Dynotch.app/Contents/Info.plist) -> /Applications/Dynotch.app"
