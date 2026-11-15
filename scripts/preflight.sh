#!/usr/bin/env bash
# Checks the current commit on GitHub (lint, build, tests) before it is pushed to main.
# Pushes HEAD to the "preflight" branch and waits for the Preflight workflow, which never
# reports a failed run. Exits non-zero and prints the findings if the commit is not clean.
#
# Usage: ./scripts/preflight.sh && git push origin main
set -euo pipefail

SHA="$(git rev-parse HEAD)"
git diff --quiet HEAD || { echo "error: commit your changes first"; exit 2; }

git push -q origin "HEAD:refs/heads/preflight"

RUN=""
for _ in $(seq 1 30); do
  RUN="$(gh run list --workflow preflight.yml --limit 5 --json databaseId,headSha \
    -q "[.[] | select(.headSha == \"$SHA\")][0].databaseId")"
  [[ -n "$RUN" ]] && break
  sleep 2
done
[[ -n "$RUN" ]] || { echo "error: preflight run for $SHA not found"; exit 2; }

gh run watch "$RUN" --interval 15 > /dev/null 2>&1 || true

LOG="$(gh run view "$RUN" --log 2>/dev/null | sed -E 's/^[^\t]*\t[^\t]*\t[^ ]* //')"
RESULT="$(grep -E "^PREFLIGHT_RESULT sha=$SHA" <<< "$LOG" | tail -1 || true)"

if [[ "$RESULT" == *"lint=pass tests=pass" ]]; then
  grep -E "Test run with" <<< "$LOG" | tail -1 || true
  echo "preflight passed: $RESULT"
  exit 0
fi

echo "preflight FAILED: ${RESULT:-no result line (setup problem?)}"
grep -E "(warning|error):|✘|##\[error\]" <<< "$LOG" | grep -v "PREFLIGHT_RESULT" | sort -u | head -40 || true
exit 1
