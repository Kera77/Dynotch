# Dynotch – notes for Claude

Personal macOS notch app (SwiftUI + AppKit agent app, no sandbox, Swift 6 strict concurrency,
XcodeGen `project.yml`). The owner writes in Hungarian: **answer in Hungarian**. The app's UI
text is English. Requirements live in `docs/SPEC.md` (Hungarian, numbered rows such as `B-8`,
`N-10`; check that a number is free before using it), changes in `CHANGELOG.md` (`[Unreleased]`).

## Checking a change

Run `./scripts/check.sh` after every change (swiftlint --strict + xcodebuild test, ~30 s; prints
`CHECK lint=… tests=…`). On lint or compile errors use the `swiftlint-rules` skill.
A new privacy-sensitive API (Bluetooth, Speech, camera…) needs its `NS…UsageDescription` in
`project.yml`, or macOS kills the app at launch; tests do not catch launch crashes.

## Releasing

Only when the owner approves a deploy; then follow the `release` skill step by step.

## Where things are

- `Dynotch/Sources/Notch/` – the notch panel (one `NotchController` per display, `NotchManager`).
- `Dynotch/Sources/Features/<Module>/` – modules. `App/AppServices.swift` lists the services,
  `App/Theme.swift` the shared colours, motion and controls.
- Logs: `~/Library/Logs/Dynotch/*.log` (no message content is logged).

## Privacy

- Never read the Claude Code credentials (keychain) from the shell; only the app reads them.
- The owner's e-mail address and other personal data must not go into requests to outside services.
- The repository is public: no keys, tokens or screenshots in it.

## Keeping sessions small

Read only the part of a file you need (`grep -n`, then `sed -n a,bp`); filter long command
output (`check.sh` and `preflight.sh` already print one result line). Commit after each
approved package so the git status at session start stays short.
