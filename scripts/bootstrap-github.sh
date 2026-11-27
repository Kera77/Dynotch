#!/usr/bin/env bash
# One-time setup: creates the GitHub repo, pushes main, configures labels & branch protection.
# Usage: ./scripts/bootstrap-github.sh [--public]
set -euo pipefail

VISIBILITY="--private"
[[ "${1:-}" == "--public" ]] && VISIBILITY="--public"

gh auth status >/dev/null

gh repo create Wingmate "$VISIBILITY" \
  --description "Wingmate – macOS app" \
  --source . --remote origin --push

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

gh repo edit "$REPO" \
  --enable-auto-merge \
  --delete-branch-on-merge \
  --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false

for label in "bug:d73a4a" "enhancement:a2eeef" "ci:0e8a16" "release:5319e7"; do
  gh label create "${label%%:*}" --color "${label##*:}" --force --repo "$REPO"
done

# Branch protection (requires public repo or a paid plan for private repos)
gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<JSON || \
  echo "warning: branch protection not applied (private repo on free plan?)"
{
  "required_status_checks": { "strict": true, "contexts": ["SwiftLint", "Build & Test"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON

echo "Done: https://github.com/$REPO"
