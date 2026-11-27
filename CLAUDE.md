# Wingmate – notes for Claude

Personal macOS notch app (SwiftUI + AppKit agent app, no sandbox, Swift 6 strict concurrency,
XcodeGen `project.yml`). The owner writes in Hungarian: **answer in Hungarian**. The app's UI
text is English. Requirements live in `docs/SPEC.md` (Hungarian, numbered rows such as `B-8`,
`N-10`; check that a number is free before using it), changes in `CHANGELOG.md` (`[Unreleased]`).
When a request mixes fixes or changes with something new that needs specifying, write the SPEC rows
first, then do all the fixes and the new work together in one go.
Unplanned ideas live in `docs/BACKLOG.md`: read or add to it only when the owner asks about the
backlog or asks to put something there.

## Checking a change

Run `./scripts/check.sh` after every change (swiftlint --strict + xcodebuild test, ~30 s; prints
`CHECK lint=… tests=…`). On lint or compile errors use the `swiftlint-rules` skill.
A new privacy-sensitive API (Bluetooth, Speech, camera…) needs its `NS…UsageDescription` in
`project.yml`, or macOS kills the app at launch; tests do not catch launch crashes.

## Releasing

Only when the owner approves a deploy; then follow the `release` skill step by step.
A deploy is a **test build** (`1.x.y`, y+1, GitHub prerelease, only the owner's app gets it);
only when the owner approves a tested version for everyone does `1.(x+1).0` go out (spec U-6).
Wording: "mehet" (or any plain deploy approval) always means the next **test build**; only
"mehet publikussá" (publish it) means the public `1.(x+1).0` release. Once the
new version is installed and running on the Mac, always send the owner a list of what to test
in it (grouped by feature, with the log to send if something fails).

## Where things are

- `Wingmate/Sources/Notch/` – the notch panel (one `NotchController` per display, `NotchManager`).
- `Wingmate/Sources/Features/<Module>/` – modules. `App/AppServices.swift` lists the services,
  `App/Theme.swift` the shared colours, motion and controls.
- Logs: `~/Library/Logs/Wingmate/*.log` (no message content is logged).

## New modules

Every module is resizable from its bottom right corner (spec RS-1…RS-6): a new `FeatureID` is
resizable automatically, so its view must fill the size it gets (`maxWidth/maxHeight: .infinity`,
lists and grids that grow, no fixed panel-wide frames). Side lists scale with
`Responsive.share(_:of:in:)` and `.readWidth(_:)` (`App/Responsive.swift`). Check it small and large.

## Onboarding stays current

The first-launch tour and the per-module first-use tips (SPEC OB-14…OB-29) must match the app.
Whenever a module or feature is added, or a gesture, button or setting location changes, update
the affected tour step and the module's tip in the same change, without being asked (a new
`FeatureID` needs a new tip and a 2–3 sentence description in `OnboardingModuleTexts`; tests check
this). Mention it in the CHANGELOG entry.
Every user-visible new feature or change also gets a short line (icon, title, one sentence) in
`WhatsNew.releases` under the version being released (SPEC WN-4): after an update the app shows
these once as "What's new". A test fails if the running version has no entry.

## Privacy

- Never read the Claude Code credentials (keychain) from the shell; only the app reads them.
- The owner's e-mail address and other personal data must not go into requests to outside services.
- The repository is public: no keys, tokens or screenshots in it.

## Keeping sessions small

Read only the part of a file you need (`grep -n`, then `sed -n a,bp`); filter long command
output (`check.sh` and `preflight.sh` already print one result line). Commit after each
approved package so the git status at session start stays short.

- One approved package = one session: after the release and the test list, tell the owner a new
  session is worth starting.
- Do not re-read a file you just edited; make several small edits in one step and run
  `check.sh` once per coherent set of changes, not after every tiny edit.
- Before adding a SPEC row, `grep` that its number is free.
- Keep replies short: the result, the risks, the open questions.
- Do not start subagents on your own. When one would clearly help (e.g. two independent
  features in parallel), propose it with the reason and the extra cost; start it only after the
  owner approves.
