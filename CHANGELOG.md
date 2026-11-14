# Changelog

## [Unreleased]

## [0.3.1] - 2026-11-14

### Fixed
- Release signing: the self-signed identity is now found in CI (0.3.0 was never published).

## [0.3.0] - 2026-11-14

### Added
- Calendar feature: events of the next 7 days from macOS Calendar (iCloud, Google…), grouped by day.
- Join button for Zoom, Google Meet, Teams and Webex links (Outlook Safe Links unwrapped).
- Upcoming event indicator beside the closed notch with a minute countdown (configurable 1–30 min lead time).
- Calendar settings tab: access status, indicator toggle, lead time.
- Releases are signed with a stable self-signed certificate, so privacy permissions survive updates.

### Changed
- Removed the feature title from the right side of the menu bar.
- Opened panel is 30 pt taller to fit the event list.

## [0.2.1] - 2026-11-14

### Fixed
- Panel no longer opens and closes repeatedly when the pointer is pushed to the very top edge of the screen.

## [0.2.0] - 2026-11-13

### Added
- Notch panel: opens on hover, stays open while the pointer is inside, closes after a configurable delay (0–3 s).
- Top menu bar with feature icons; two-finger horizontal swipe switches features (no wrap-around, bounce at the ends).
- Panel reopens with the last used feature, also after restart.
- Right-click menu: Settings…, About, Quit.
- Virtual notch on displays without a physical notch.
- Settings window: launch at login, close delay, enable and reorder features.
- Placeholder features: Home (clock/date) and Info (version, display, notch size).

### Changed
- Dynotch is now a background agent app (no Dock icon, no main window).
- App Sandbox disabled (needed for the upcoming volume/brightness HUD).

## [0.1.1] - 2026-11-12

### Changed
- Release builds are ad-hoc signed for personal use; Apple notarization removed.
- `make install` installs the latest GitHub release to /Applications.

## [0.1.0] - 2026-11-12

### Added
- Initial macOS app skeleton (SwiftUI, macOS 14+): main window, Settings with launch-at-login.
- XcodeGen project, SwiftLint, Swift Testing unit tests, Makefile.
- GitHub Actions CI and tag-based release workflow with optional Developer ID signing and notarization.
