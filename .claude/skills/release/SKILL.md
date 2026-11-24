---
name: release
description: Dynotch's release order (version bump, CHANGELOG, SPEC, preflight, push, tag, CI and release, install on the Mac). Use when the owner approves a deploy or release, or asks how releasing works.
---

# Releasing Dynotch

Deploy only when the owner has approved it. Never push untested code to `main` (failed CI
e-mails the owner); never install a build whose tests have not all passed.

1. `./scripts/check.sh` passes (`CHECK lint=pass tests=pass`).
2. Bump `MARKETING_VERSION` in `project.yml`. In `CHANGELOG.md` turn `[Unreleased]` into
   `[X.Y.Z] - YYYY-MM-DD` (keep an empty `[Unreleased]` above it). In `docs/SPEC.md` update the
   status line (`> Állapot: **vX.Y elfogadva** · Utolsó módosítás: …`), add a row to the version
   table (section 7, newest on top) and the requirement rows. Commit.
3. `./scripts/preflight.sh` pushes HEAD to the scratch `preflight` branch and runs lint, build
   and tests there; it prints `PREFLIGHT_RESULT sha=… lint=… tests=…`. Fix with further commits
   until it passes.
4. `git push origin main`, then `git tag vX.Y.Z` and `git push origin vX.Y.Z`. `release.yml`
   waits for CI on the same commit, builds, signs with the self-signed "Dynotch Self-Signed"
   certificate and publishes `Dynotch-X.Y.Z.zip/.dmg`, `Dynotch.dmg` (fixed name, for Homebrew)
   and `SHA256SUMS.txt`. Watch both runs with `gh run watch <id> --exit-status` in the
   background. Runners sometimes cancel queued jobs after ~15 min: `gh run rerun <id> --failed`,
   do not change the code for it.
5. Only when **both** the main CI run and the release succeeded, install as the very last
   step: restart the app (`osascript -e 'quit app "Dynotch"'; open /Applications/Dynotch.app`);
   it finds the release within ~20 s and updates itself (`~/Library/Logs/Dynotch/updates.log`).
   Fallback: `./scripts/install.sh vX.Y.Z`.
   Going back (spec RF-21): *Settings › About › Go back to X* installs the version it was updated
   from and turns automatic updates off. If the new build does not even start:
   `./scripts/install.sh v<previous>`; for an older tag it also turns automatic updates off
   (`defaults write com.peterkereki.Dynotch updatesManual -bool true`), or the app would update
   itself again. Turn them back on in Settings › About once a fixed version is out.
6. Check that it keeps running: `pgrep -x Dynotch` after ~30 s, and no new
   `~/Library/Logs/DiagnosticReports/Dynotch-*.ips`. A launch crash after adding a
   privacy-sensitive API means a missing `NS…UsageDescription` in `project.yml` (0.42 did this;
   0.42.1 fixed it). A build that crashes at launch cannot update itself: install the fix with
   `./scripts/install.sh`.
7. Tell the owner it is installed, with a list of what to test in this version (from the
   CHANGELOG, grouped by feature, with the log to send if something fails).

Homebrew cask: `Packaging/Homebrew/Casks/dynotch.rb`, copied to the tap repo
`Kera77/homebrew-dynotch` (Homebrew 7 needs `brew trust kera77/dynotch`).
