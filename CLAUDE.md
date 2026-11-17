# Dynotch – notes for Claude

Personal macOS notch app (SwiftUI + AppKit agent app, no sandbox, Swift 6 strict concurrency,
XcodeGen `project.yml`). The owner writes in Hungarian: **answer in Hungarian**. The app's UI
text is English. Requirements live in `docs/SPEC.md` (Hungarian, numbered rows such as `B-8`,
`N-10`; check that a number is free before using it), changes in `CHANGELOG.md`.

## No Xcode on this Mac

Builds and tests only run on GitHub (macos-26 runners). Locally only a rough type check works:

```bash
swiftc -typecheck -swift-version 6 -target arm64-apple-macos15.0 $(find Dynotch/Sources -name '*.swift') 2>&1 \
  | grep "error:" | grep -v StateMacro      # @State macro errors are expected locally
```

The CI SDK can differ from the local one (e.g. `CGEventField(rawValue:)` is failable there).

## Release order (always)

1. Commit locally. Bump `MARKETING_VERSION` in `project.yml`, add a `CHANGELOG.md` entry and
   update `docs/SPEC.md` (status line, version table, the requirement rows).
2. `./scripts/preflight.sh` – pushes HEAD to the scratch `preflight` branch, runs lint + build +
   tests there and prints `PREFLIGHT_RESULT ... lint=… tests=…`. Fix with further commits until it
   passes. Never push untested code to `main` (failed CI e-mails the owner).
3. `git push origin main`, then tag `vX.Y.Z` and push the tag. `release.yml` waits for CI on the
   same commit, builds, signs with the self-signed "Dynotch Self-Signed" certificate (secrets
   `SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`) and publishes `Dynotch-X.Y.Z.zip/.dmg`,
   `Dynotch.dmg` (fixed name, for Homebrew) and `SHA256SUMS.txt`.
4. Only when **both** the main CI run and the release succeeded: install on the Mac, as the very
   last step. Normally restart the running app (`osascript -e 'quit app "Dynotch"'; open
   /Applications/Dynotch.app`); it finds the release within ~20 s and updates itself
   (`~/Library/Logs/Dynotch/updates.log`). Fallback: `./scripts/install.sh vX.Y.Z`.
   Never install a build whose tests have not all passed.

GitHub macOS runners sometimes cancel queued jobs after ~15 min: rerun them
(`gh run rerun <id> --failed`), do not change the code for it.

## SwiftLint (strict) – rules that bit before

- `file_length` 400, `type_body_length` 250, `function_body_length` 50, `cyclomatic_complexity` 10:
  move code into extensions / separate files (e.g. `NotchController+*.swift`, `NotchView+Pages.swift`).
- `line_length` 140; `identifier_name` at least 3 characters (no `to`, `up`);
  `force_unwrapping`; `sorted_imports`; `empty_count`; `is_disjoint`;
  `optional_data_string_conversion` (use `String(bytes:encoding:)`);
  `multiple_closures_with_trailing_closure`; `legacy_swiftui_aspect_ratio` (use `scaledToFit()`).
- Swift Testing: no mutating calls inside `#expect`; compare floating point values with a tolerance.
- Closures passed to `Task.detached` must not capture main-actor state: call plain static functions.

## Where things are

- `Dynotch/Sources/Notch/` – the notch panel (one `NotchController` per display, `NotchManager`).
- `Dynotch/Sources/Features/<Module>/` – modules (calendar, notifications, badges, calls, Claude
  chat, batteries, updates…). `App/AppServices.swift` lists the shared services.
- Logs for troubleshooting: `~/Library/Logs/Dynotch/*.log` (no message content is logged).
- Homebrew cask: `Packaging/Homebrew/Casks/dynotch.rb`, copied to the tap repo
  `Kera77/homebrew-dynotch` (Homebrew 7 needs `brew trust kera77/dynotch`).

## Privacy

- Never read the Claude Code credentials (keychain) from the shell; only the app reads them, with
  the user's macOS consent.
- The owner's e-mail address and other personal data must not go into requests to outside services.
- The repository is public: no keys, tokens or screenshots in it.
