#!/usr/bin/env bash
# Moves Homebrew from the old tap and cask (kera77/dynotch, dynotch) to kera77/wingmate (spec RN-12).
# Run once, right after the first public Wingmate release (1.10.0) is out, as its Wingmate.dmg is
# what the cask loads. The old tap repo keeps its name: Homebrew refuses a renamed tap's redirect.
set -euo pipefail

NEW="Kera77/homebrew-wingmate"
OLD="Kera77/homebrew-dynotch"
gh release view --repo Kera77/Wingmate --json assets --jq '.assets[].name' | grep -qx 'Wingmate.dmg' \
  || { echo "error: the latest public release has no Wingmate.dmg yet"; exit 1; }

put() { # repo, path in it, local file
  local sha
  sha=$(gh api "repos/$1/contents/$2" --jq '.sha' 2>/dev/null) || sha=""
  gh api -X PUT "repos/$1/contents/$2" -f message="Wingmate: $2" \
    -f content="$(base64 < "$3" | tr -d '\n')" ${sha:+-f sha="$sha"} --jq '.content.path'
}

# GitHub keeps a redirect after a repo rename, so "gh repo view" alone would accept the old tap.
[[ "$(gh api "repos/$NEW" --jq '.full_name' 2>/dev/null || true)" == "$NEW" ]] \
  || gh repo create "$NEW" --public --description "Homebrew tap for Wingmate"
[[ "$(gh api "repos/$NEW" --jq '.full_name')" == "$NEW" ]] || { echo "error: $NEW redirects elsewhere"; exit 1; }
put "$NEW" Casks/wingmate.rb Packaging/Homebrew/Casks/wingmate.rb
put "$NEW" cask_renames.json Packaging/Homebrew/cask_renames.json
put "$NEW" README.md Packaging/Homebrew/README.md

# The old tap sends installed dynotch casks to the new tap, where cask_renames.json names them wingmate.
put "$OLD" tap_migrations.json Packaging/Homebrew/tap_migrations.json
put "$OLD" README.md Packaging/Homebrew/README-old-tap.md
for path in Casks/dynotch.rb Casks/wingmate.rb cask_renames.json; do
  old=$(gh api "repos/$OLD/contents/$path" --jq '.sha' 2>/dev/null) || old=""
  [[ -z "$old" ]] || gh api -X DELETE "repos/$OLD/contents/$path" \
    -f message="Dynotch is now Wingmate (kera77/wingmate)" -f sha="$old" --jq '.commit.sha'
done
echo "==> Done. Check: brew update && brew info --cask kera77/wingmate/wingmate (an installed dynotch: see Packaging/Homebrew/README.md)"
