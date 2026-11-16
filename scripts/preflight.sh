#!/usr/bin/env bash
# Checks the current commit on GitHub (lint, build, tests) before it is pushed to main.
# Pushes HEAD to the "preflight" branch and waits for the Preflight workflow, which never
# reports a failed run. Exits non-zero and prints the findings if the commit is not clean.
#
# Usage: ./scripts/preflight.sh && git push origin main
set -euo pipefail

SHA="$(git rev-parse HEAD)"
git diff --quiet HEAD || { echo "error: commit your changes first"; exit 2; }

# The preflight branch is a scratch branch: overwrite whatever is there.
git push -q --force origin "HEAD:refs/heads/preflight"

RUN=""
for _ in $(seq 1 30); do
  RUN="$(gh run list --branch preflight --limit 5 --json databaseId,headSha \
    -q "[.[] | select(.headSha == \"$SHA\")][0].databaseId")"
  [[ -n "$RUN" ]] && break
  sleep 2
done
[[ -n "$RUN" ]] || { echo "error: preflight run for $SHA not found"; exit 2; }

# Same commit pushed again (no new run), or the run was cancelled/failed to start: rerun it.
if [[ "$(gh run view "$RUN" --json status -q .status)" == "completed" ]]; then
  gh run rerun "$RUN" > /dev/null
  sleep 5
fi

gh run watch "$RUN" --interval 15 > /dev/null 2>&1 || true

# Log lines look like "job<TAB>step<TAB>timestamp text"; keep only the text.
LOG="$(gh run view "$RUN" --log 2>/dev/null | cut -f3- | cut -d' ' -f2-)"
RESULT="$(grep -oE "PREFLIGHT_RESULT sha=$SHA lint=[a-z]+ tests=[a-z]+" <<< "$LOG" | tail -1 || true)"

if [[ "$RESULT" == *"lint=pass tests=pass" ]]; then
  grep -E "Test run with" <<< "$LOG" | tail -1 || true
  echo "preflight passed: $RESULT"
  exit 0
fi

echo "preflight FAILED: ${RESULT:-no result line (setup problem?)}"
grep -E "(warning|error):|✘|##\[error\]" <<< "$LOG" | grep -v "PREFLIGHT_RESULT" | sort -u | head -40 || true
exit 1
