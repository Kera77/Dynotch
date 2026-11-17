# Changelog

## [Unreleased]

## [0.29.0] - 2026-11-17

### Added
- Switching Spaces: whatever stands beside the closed notch is drawn into it and unfolds again
  with a soft spring (off with Reduce Motion).

### Changed
- Settings › Features is now "Modules"; rows can be dragged to reorder them.
- Clicking into a notification's reply field pins the notch, so it stays open while typing.
- "Pin" is unticked for modules without a shortcut.

## [0.28.0] - 2026-11-17

### Fixed
- On displays with a notch the feature icons ran behind the notch. Now only as many are shown as
  fit; swiping over them moves them without switching, a click switches.
- A right click on an app badge could list other apps' notifications until the list changed.

## [0.27.0] - 2026-11-17

### Added
- Releases also carry `Dynotch.dmg` under a fixed name, for the Homebrew cask.
- Automatic updates: Dynotch checks GitHub every 6 hours, verifies the download (checksum,
  version, signature), replaces itself and restarts. Settings › About: on/off and "Check Now".
- Homebrew: `brew tap kera77/dynotch && brew trust kera77/dynotch && brew install --cask dynotch`.

## [0.26.0] - 2026-11-16

### Added
- Batteries: a feature listing the battery level of the Mac and of every connected device. A
  device below 20 % is shown beside the notch (its icon on the left, the level in red on the
  right) until its warning is closed.
- A button beside the keyboard lock turns "focus follows mouse" on and off.
- Shortcuts: pinning the notch open is chosen per feature (a "Pin" checkbox in Settings › Features).

### Changed
- All macOS system notices are shown, under one "System Settings" switch.
- "Claude finished" names the project that was actually worked on, not the folder the session started in.
- Rings and countdowns beside the notch are larger and sit on whole pixels, so they are sharp on
  non-Retina displays.
- The reminder count in the menu bar is closer to its icon and centred.
- Claude: the button that hides the chat list sits beside "New chat".

### Fixed
- A shortcut pressed while the notch was already open by hover closed it instead of pinning it.

## [0.25.0] - 2026-11-16

### Added
- Preview on hover: optionally the notch first shows one line about the current feature, and opens
  fully after a set time or on a click.
- Claude: Claude Code's own sessions appear in the chat list and can be continued; the list of
  chats can be hidden; a menu bar icon with the same chat.
- Search fields for the app lists in the App badges and Notifications settings.

### Changed
- "Claude finished" only appears when Claude Code has nothing left running in the background.
- Focus follows mouse no longer switches between the windows of the active app.
- The Claude feature has Claude's mark in the settings too.

### Fixed
- No notice appeared when Claude answered in the chat while the notch was closed.
- Windows flickered while an app showed a pop-up.

## [0.24.0] - 2026-11-16

### Added
- Claude in the notch: a chat feature with the earlier chats on the left and the conversation on
  the right. While Claude works, its icon and moving dots show beside the closed notch; when the
  answer is ready a line hangs under the notch until you hover it, which opens the chat.
- A shortcut for pinning the notch open.

### Changed
- App badges: a click opens the app, a right click shows its unopened notifications.
- Notifications that were read or answered in their app disappear from the notch too.
- Incoming calls show only the caller's name; a reply is sent as a text, or as an iMessage if
  there is no number.
- The lock (pin) is blue while on, like the keyboard lock.

### Fixed
- The Beeper token no longer makes macOS ask for the keychain password (it is kept in a private file).
- Focus follows mouse made windows flicker while an app showed a dialog.

## [0.23.0] - 2026-11-16

### Added
- Notes: to-do lists. A toolbar button (⇧⌘L) turns lines into items; a click on the circle checks
  an item and moves it to the end of the list; Return starts the next item. Notes with Apple Notes
  lists can be made editable ("Make editable").
- Shortcuts: a global shortcut per feature (Settings › Features), optionally pinning the notch open.
- A notice under the notch when Claude Code finishes a task; it stays until swiped up.

### Fixed
- Incoming calls showed "Notification Center" instead of the caller; the caller's name and
  Contacts picture are shown, and the text reply reports why it could not be sent.

## [0.22.0] - 2026-11-16

### Added
- Notifications: one row per sender; a click opens it with every message and a reply field.

### Changed
- A click on an app badge opens that app's unopened notifications in the notch instead of the app.

### Fixed
- Incoming calls did not appear: the macOS call banner lives in Notification Center's
  screen-sized window, which was skipped.

## [0.21.0] - 2026-11-16

### Added
- Incoming calls in the notch: caller, Answer, Decline, and a message button whose text field
  sends a text to the caller on Enter (then declines the call).
- Keyboard lock button next to the settings gear: blocks all keys while on, for cleaning the keyboard.
- App badges: white Beeper, Google Chat and Gmail icons.

### Changed
- An app badge stops pulsing once the pointer is on it.

## [0.20.0] - 2026-11-16

### Added
- App badges: the unread count of chosen apps (from their Dock badges) left of the notch, after a
  thin separator. Hidden without unread notifications; pulses for 5 minutes after a new one;
  click opens the app; drag to reorder at the notch or in Settings.
- Settings › App badges: add any installed app, turn it on or off, pick a built-in icon or your own image.

### Changed
- The Claude icon beside the notch is white.
- The AI usage ring beside the notch is blue up to 70 %, orange up to 90 %, red above.

## [0.19.1] - 2026-11-16

### Changed
- Same app as 0.19.0. Releases now wait for CI before building, so they no longer queue for a macOS runner at the same time as CI.

## [0.19.0] - 2026-11-16

### Added
- Notes: formatting toolbar (Title, Heading, Subheading, Body, bold, italic, underline,
  strikethrough) and Apple Notes' shortcuts; formatting is saved to Notes.

### Changed
- Level rings show the value in the middle and are sharper (volume, brightness, AI session).
- The volume and brightness icon no longer changes while the level changes.

### Fixed
- After swiping the meeting announcement away, its name opened again while the pointer stayed on it.

## [0.18.0] - 2026-11-16

### Added
- Volume and brightness beside the notch instead of the macOS overlay: white icon on the left,
  white ring filling clockwise on the right; Option-Shift for finer steps.
- AI Usage: "Show at notch" keeps the session ring beside the notch below 70 % too.
- Settings: the meeting lead time can be typed in.
- Cut, copy, paste and select all work in every text field; Paste button for the Beeper token.

## [0.17.0] - 2026-11-16

### Added
- New app icon.
- Notifications: X and "clear all" on the hover card; remove one or all in the Notifications feature.

### Changed
- Calendar: the date under a meeting's name is blue; the full view uses the same Join button.

### Fixed
- A swipe that switched to the calendar also stepped days when it continued over the day strip;
  stepping days now needs a new swipe.

## [0.16.1] - 2026-11-16

### Fixed
- Native banners are also searched among Notification Center's direct children, not only its windows.

### Added
- Diagnostics: Notification Center state when a banner is not found; shape of identifiers in web notifications.

## [0.16.0] - 2026-11-16

### Added
- Reply field for every chat notification. Google Chat (no API): the conversation is opened in the
  app that posted the notification and the text is typed in (needs Accessibility).
- System Settings notices (login and background items, software update, privacy) in the notch.
- Settings › Focus tab with a description of focus-follows-mouse.
- Trackpad feedback when the notch opens and on feature and day swipes.

## [0.15.0] - 2026-11-16

### Added
- Meeting announcement: when a meeting enters the countdown, its name opens below the notch and
  stays until swiped away with two fingers up.

### Changed
- The AI usage indicator beside the notch shows only the session limit, and only from 70 %.

## [0.14.0] - 2026-11-16

### Added
- Notch notification when the AI session resets.
- "Open … to reply" button for notifications that cannot be answered from the notch (Google Chat).

### Changed
- Hovering a notification shows only that sender's new messages: the name once, the texts below.
- Notes and Reminders use a narrower panel in the notch.
- Reminders: room left of the circles.

### Fixed
- The "limit reached" usage notification came every hour: a moving reset time no longer starts a
  new period, so every 10 % step is announced once.

## [0.13.1] - 2026-11-16

### Fixed
- "via chat.google.com" and similar source lines are no longer shown in notifications.

## [0.13.0] - 2026-11-16

### Added
- Hovering a notification peek lists every new notification, one under the other; the peek shows
  "+N" when there are more.
- Reply to Beeper messages from the notch (Beeper Desktop API; token in Settings › Notifications).

## [0.12.0] - 2026-11-16

### Added
- Settings › Features: choose per feature whether it also has a menu bar icon.

### Changed
- The Claude usage feature is called AI Usage; beside the notch it is a ring without text.
- Icons left of the notch are full size.
- The AI Usage panel in the notch is tall enough to show every limit without scrolling.

### Fixed
- macOS kept asking for the password to read Claude Code's login: the token is now read with the
  same tool Claude Code stores it with, and kept in memory until it expires.
- Clicking a menu bar icon while its panel is open closes it (and unpins a pinned panel) instead of
  opening it again.

## [0.11.4] - 2026-11-16

### Fixed
- The model-scoped weekly limit is called "Fable limit" (as in Claude's own usage screen) instead of a second "Weekly".

## [0.11.3] - 2026-11-16

### Fixed
- Claude usage shows every limit, not only the one currently binding.

## [0.11.2] - 2026-11-16

### Changed
- Usage diagnostics log the response's shape (keys and types, no values).

### Fixed
- Claude usage reads the current "limits" list, so per-model limits (e.g. Fable) appear.

## [0.11.0] - 2026-11-16

### Changed
- The whole app is in English.
- Claude usage moved from the menu bar ring to the notch: Claude icon on the left, a usage capsule
  on the right next to the meeting countdowns; hovering shows used, left and reset time per limit,
  and an X hides it until usage reaches the next 10 %.

## [0.10.0] - 2026-11-16

### Added
- Claude usage feature (notch and menu bar): session, weekly and per-model limits with reset times,
  using Claude Code's login; menu bar ring with percentages on hover; notch notification from 70 %,
  again at every 10 %.

### Changed
- Day strip: a longer swipe is needed per day.
- The day's event list starts at the meeting in progress or the next one.

## [0.9.0] - 2026-11-16

### Added
- Focus follows the mouse without raising windows (like AutoRaise with raising off): the app under
  the pointer gets the keyboard, window order stays as it is. Setting on the General tab.

### Fixed
- Reminders stayed on "asking for access" after access was granted: the permission is checked
  again on every open and while waiting, and the store reloads when access arrives.

## [0.8.0] - 2026-11-16

### Added
- Reminders feature in the notch and the menu bar (Apple Reminders via EventKit): quick add with
  date and "@list" recognition, list picker, upcoming reminders, tasks with circle checkboxes,
  recently completed filter, open count on the menu bar icon.

### Changed
- Swiping over the calendar's day strip steps through the days.

### Fixed
- Native banners are now closed as soon as they appear (Notification Center window events),
  not only when a poll happens to find them.

## [0.7.6] - 2026-11-16

### Changed
- The X in the countdown hover label sits at the right edge.

### Added
- Diagnostics: accessibility structure of Notification Center when a banner can't be closed (no text).

## [0.7.5] - 2026-11-16

### Added
- Native macOS banners of notifications shown in the notch are closed automatically
  (needs Accessibility permission; setting on the Notifications tab).

### Changed
- The X in the countdown hover label sits at the left edge.
- Hiding a countdown is quick; the remaining countdowns and their outlines move up at once.

## [0.7.4] - 2026-11-16

### Changed
- Meeting countdowns: the black area is asymmetric, on the left it only reaches the icon.

### Added
- X button in the hover label hides that meeting's countdown.

### Fixed
- Cmd-drag reordering in the top row was jerky and stopped after one or two places.

## [0.7.3] - 2026-11-16

### Changed
- Browser notifications (Zen, Chrome, Firefox…) are attributed to web apps by site as well.
- Diagnostics log the site and field names of recent browser notifications.

## [0.7.2] - 2026-11-16

### Fixed
- Gmail and Google Chat notifications coming from a browser (Zen, Chrome, Safari…) or under the
  shared Safari Web App identifier are attributed to the installed web app by their site.
- Only one icon on the left of the meeting countdowns.

### Added
- Notification diagnostics: per-app record counts and a per-notification log without content.

## [0.7.1] - 2026-11-16

### Added
- Reorder the features by dragging their icons in the notch's top row with Command held.
- Meeting countdowns side by side: every running meeting and every one starting soon (up to 3).
- Hovering a countdown writes the meeting's name and time below the notch.

## [0.7.0] - 2026-11-16

### Added
- Notes feature in the notch and in the menu bar: sidebar with Apple Notes folders and notes,
  plain text editor with autosave to Notes, local draft with "Save to Notes", conflict detection.
  Notes with lists, tables, images, links or attachments open read-only.

## [0.6.3] - 2026-11-16

### Changed
- Hovering a notification peek opens a card with just that notification instead of the
  Notifications feature.
- Meeting countdown outline now shows the time left: it starts full and runs down clockwise.

## [0.6.2] - 2026-11-16

### Changed
- Menu bar calculator redesigned as a popover: arrow pointing at the icon, rounded dark panel,
  status bar with result count, lock and a "copy all" button.

### Fixed
- Copy, cut, paste, select all and undo shortcuts now work in the calculator.

## [0.6.1] - 2026-11-16

### Added
- Clicking a calculator result copies it to the clipboard.

### Fixed
- Calculator results were not shown: they were drawn outside the text view's drawing area.
  They now live in their own column view.

## [0.6.0] - 2026-11-16

### Added
- Calculator notepad feature: type calculations line by line, results appear in green on the right.
- Menu bar icon that drops the same calculator down below it.
- Lock button in the notch's top row and on the menu bar panel: keeps the panel open.

### Changed
- Settings tabs are icons; the tab name is written beside them (and on hover).

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
