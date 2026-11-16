#!/usr/bin/env bash
# Turns on branch protection for main (needs a public repo or GitHub Pro):
# CI (SwiftLint + Build & Test) must pass, no force pushes, no deletion.
# Admins can still push directly; the preflight script keeps those pushes green.
set -euo pipefail
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<JSON
{
  "required_status_checks": { "strict": false, "contexts": ["SwiftLint", "Build & Test"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "Branch protection on for $REPO main"
