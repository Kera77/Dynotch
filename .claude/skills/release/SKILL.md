---
name: release
description: Wingmate's release order (version bump, CHANGELOG, SPEC, preflight, push, tag, CI and release, install on the Mac). Use when the owner approves a deploy or release, or asks how releasing works.
---

# Releasing Wingmate

Deploy only when the owner has approved it. Never push untested code to `main` (failed CI
e-mails the owner); never install a build whose tests have not all passed.

## Two kinds of release (spec U-6…U-10)

- **Test build** – the default for "deploy" and for a plain "mehet": only the owner gets it. Bump the **last** number
  (1.7.2 → 1.7.3). The tag makes `release.yml` publish a GitHub *prerelease*; only apps with
  *Settings › About › Beta updates* on install it. Give it its own `WhatsNew` entry. There is no
  test list in the app (spec TL-5): what to test goes only in the message to the owner (step 7).
- **Publish to everyone** – only when the owner explicitly says "mehet publikussá" (or otherwise
  clearly says to publish to everyone); a plain "mehet" is never this. Bump the **middle** number, last becomes 0 (1.7.4 → 1.8.0), from the approved
  commit with no code changes besides the release bookkeeping. Merge the `WhatsNew` entries of the
  cycle's test builds into one `1.8.0` entry (drop the test entries), and the CHANGELOG sections
  of the cycle into `[1.8.0]`. Add one row to the SPEC version table for 1.8.0.

The steps below are the same for both.

1. `./scripts/check.sh` passes (`CHECK lint=pass tests=pass`).
2. Bump `MARKETING_VERSION` in `project.yml`. In `CHANGELOG.md` turn `[Unreleased]` into
   `[X.Y.Z] - YYYY-MM-DD` (keep an empty `[Unreleased]` above it). In `docs/SPEC.md` update the
   status line (`> Állapot: **vX.Y elfogadva** · Utolsó módosítás: …`), add a row to the version
   table (section 7, newest on top) and the requirement rows. Commit.
3. `./scripts/preflight.sh` pushes HEAD to the scratch `preflight` branch and runs lint, build
   and tests there; it prints `PREFLIGHT_RESULT sha=… lint=… tests=…`. Fix with further commits
   until it passes.
4. `git push origin main`, then `git tag vX.Y.Z` and `git push origin vX.Y.Z`. `release.yml`
   waits for CI on the same commit, builds, signs with the self-signed "Wingmate Self-Signed"
   certificate and publishes `Wingmate-X.Y.Z.zip/.dmg`, `Wingmate.dmg` (fixed name, for Homebrew)
   and `SHA256SUMS.txt`. Watch both runs with `gh run watch <id> --exit-status` in the
   background. Runners sometimes cancel queued jobs after ~15 min: `gh run rerun <id> --failed`,
   do not change the code for it.
5. Only when **both** the main CI run and the release succeeded, install as the very last
   step: restart the app (`osascript -e 'quit app "Wingmate"'; open /Applications/Wingmate.app`);
   it finds the release within ~20 s and updates itself (`~/Library/Logs/Wingmate/updates.log`).
   Fallback: `./scripts/install.sh vX.Y.Z`.
   Going back (spec RF-21): `./scripts/install.sh v<previous>`; for an older tag it also turns
   automatic updates off
   (`defaults write com.peterkereki.Wingmate updatesManual -bool true`), or the app would update
   itself again. Turn them back on in Settings › About once a fixed version is out.
6. Check that it keeps running: `pgrep -x Wingmate` after ~30 s, and no new
   `~/Library/Logs/DiagnosticReports/Wingmate-*.ips`. A launch crash after adding a
   privacy-sensitive API means a missing `NS…UsageDescription` in `project.yml` (0.42 did this;
   0.42.1 fixed it). A build that crashes at launch cannot update itself: install the fix with
   `./scripts/install.sh`.
7. Tell the owner it is installed (for a test build: "only you have it"; when published: "everyone
   gets it within 6 hours"), with a list of what to test in this version, grouped by feature,
   with the log to send if something fails.

Homebrew cask: `Packaging/Homebrew/Casks/wingmate.rb`, copied to the tap repo
`Kera77/homebrew-wingmate` (Homebrew 7 needs `brew trust kera77/wingmate`).
Until the first public release after the rename (1.10.0) the tap still serves the old name: at
that release rename the tap repo to `Kera77/homebrew-wingmate`, put `wingmate.rb` in its `Casks/`
and remove the old cask file there (spec RN-1).
