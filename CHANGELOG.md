# Changelog

## [Unreleased]

## [0.5.2] - 2026-11-15

### Added
- Gear button on the right of the panel's top row; settings open inside the notch by default,
  or in a separate window (new setting).
- Quit button on the About tab of the settings.
- Preflight check before commits reach main.

### Removed
- Right-click context menu.

## [0.5.1] - 2026-11-15

### Fixed
- Missing Full Disk Access is now recognized and the app offers to open the settings page.

## [0.5.0] - 2026-11-15

### Added
- Notifications in the notch: a new notification makes the closed notch peek open showing who wrote;
  hovering opens the Notifications feature with the content. Needs Full Disk Access.
- Default apps: Beeper, and the Gmail and Google Chat web apps (Gmail shows sender and subject only).
- Notification settings: peek duration (2–30 s), per-app toggles, guide for hiding native banners.

## [0.4.2] - 2026-11-15

### Fixed
- Feature switch animation: the current feature slides out opposite to the swipe and the new one
  slides in from the side you switch towards (the outgoing view sometimes moved the wrong way).

## [0.4.1] - 2026-11-15

### Added
- Meeting countdown beside the notch: yellow until the start (red in the last 3 minutes), light blue
  for the time left during the meeting; the capsule outline fills proportionally.

### Changed
- The calendar's expand button moved to the right; the last used calendar view is remembered.

### Fixed
- Expanding the calendar only flashed and grew on the next interaction. The window no longer resizes.

## [0.4.0] - 2026-11-15

### Added
- A notch panel on every connected display; displays without a notch show a visible virtual notch.
- Calendar day view: scrollable day strip with event dots, the selected day's events below.
- Full calendar view (large panel): month grid with navigation and a 14-day agenda.
- Capsule-style feature switcher in the panel's top row.

### Changed
- Join always opens the meeting in the default browser.
- Join button restyled (green capsule); event rows show weekday and start time.

## [0.3.2] - 2026-11-14

### Fixed
- Opening animation: panel content now grows together with the black background instead of appearing first.

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
