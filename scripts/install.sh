#!/usr/bin/env bash
# Downloads a Dynotch release from GitHub and installs it to /Applications.
# Usage: ./scripts/install.sh [vX.Y.Z]   (default: latest)
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

echo "Installed $(plutil -extract CFBundleShortVersionString raw /Applications/Dynotch.app/Contents/Info.plist) -> /Applications/Dynotch.app"
