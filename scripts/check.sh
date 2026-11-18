#!/usr/bin/env bash
# Lint, build and test locally with Xcode (no sudo: DEVELOPER_DIR points at it).
# Usage: ./scripts/check.sh            prints "CHECK lint=… tests=…" and the findings
set -uo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
out="${TMPDIR:-/tmp}/dynotch-check"
mkdir -p "$out"
lint=pass
tests=pass
swiftlint --strict --quiet > "$out/lint.log" 2>&1 || lint=fail
xcodegen generate > /dev/null
xcodebuild test -project Dynotch.xcodeproj -scheme Dynotch -destination 'platform=macOS' \
  -derivedDataPath "$out/DerivedData" CODE_SIGNING_ALLOWED=NO > "$out/test.log" 2>&1 || tests=fail
# The test build has the app's bundle id: left registered, System Settings' Full Disk Access
# switch can end up on it instead of /Applications/Dynotch.app (notifications then denied).
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$out/DerivedData/Build/Products/Debug/Dynotch.app" 2>/dev/null
# Tests make UserDefaults suites named "<Suite>-<UUID>" (e.g. "V045Tests-…"); remove their files,
# which otherwise pile up by thousands. Only names ending in a UUID, never an app's own file.
uuid='[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
find -E "$HOME/Library/Preferences" -maxdepth 1 -type f \
  -regex ".*/(DynotchTests|[A-Za-z]*Tests[A-Za-z-]*|V0[0-9]{2}[A-Za-z-]*)-$uuid\.plist" -delete 2>/dev/null
grep -E "(warning|error):" "$out/lint.log" | head -40
grep -E "error:|✘|Test run with|recorded an issue" "$out/test.log" | grep -v "linkd" | sort -u | head -40
echo "CHECK lint=$lint tests=$tests"
[[ "$lint" == pass && "$tests" == pass ]]
