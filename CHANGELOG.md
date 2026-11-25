# Changelog

## [Unreleased]

### Fixed

- Finder, Spotlight and Launchpad show the app as Wingmate instead of Dynotch: the plain Info.plist name now matches the file name Dynotch.app, so macOS uses the localized name (WM-3). Onboarding: no tour step or tip names the app file, so none changed.

## [1.4.0] - 2026-11-25

### Changed

- New app icon: an open notch hanging from the top edge with music and a waveform, two wing buttons under it, on frosted glass. It has a light and a dark version and follows the system appearance on macOS 26 and later (G-10). Onboarding: no tour step or tip shows the icon, so none changed.

## [1.3.1] - 2026-11-25

### Fixed

- Gmail via Apple Mail with the Primary label: Inbox mail whose copy sits in Mail's Primary mailbox counts again, so the badge and the mail notifications no longer stay at 0. When no Inbox mail carries the Primary label (its Gmail filter does not run), the whole Inbox counts instead of 0; `mail.log` notes per Gmail account whether the label mailbox exists and how much Inbox mail has it, counts only (GM-17).

### Changed

- Settings › Modules: the Swipe up sections come before the Module strip (SD-18).

## [1.3.0] - 2026-11-25

### Changed

- The tour opens from the notch instead of a separate card and keeps it open until it ends; ← → page, Esc skips. Open and close and Move between modules explain the gestures instead of waiting for them (OB-36). Onboarding: the tour steps describe this.
- First-use tips: every module and every tab of Notifications, Tools, Clipboard and Tray has its own two or three sentences covering all its functions; the rewritten tips show once after the update (OB-37).
- Settings: the long app lists (App badges › Add an app, Notifications › Apps and Websites) open right away; app icons are read once (SD-17).
- Settings: every search field looks and works the same, the Weather place search included (SD-16).

### Removed

- Settings › About › Go back to X; going back is `./scripts/install.sh vX.Y.Z` (RF-21).

## [1.2.0] - 2026-11-25

### Added

- Wings on a large display (1800 pt wide or more): two more upcoming events, up to 9 apps, 5 clipboard items a side, 8 tray files, 8 devices, and the next six hours' weather with today's high and low (PV-75).

### Changed

- What's new opens from the notch instead of a separate window: after an update the "Wingmate updated" notice stands under the notch without an X and cannot be swiped away; the first hover opens What's new in the notch, and Got it removes it. A notice that takes its place gives it back; an update without an entry shows "Fixes and small improvements" (WN-6…WN-8).
- The tour card always hangs right under the notch and can no longer be dragged; while practising it slides down under the opened notch and back (OB-34, OB-35). Onboarding: the What's new entry for this version describes it.
- The Tools module is as tall as the Pomodoro needs, without the empty band at the bottom (TM-22).

## [1.1.0] - 2026-11-25

### Added

- What's new: after an update, a card shows once what arrived since the version you had; not on a first install, where the tour runs (WN-1…WN-5).
- Settings › General › End tour, beside Replay tour: stops a running tour and turns the modules' first-use tips off; Replay turns them back on (OB-32).

### Changed

- The tour is a card under the menu bar that is exactly as big as its content; a long step scrolls while its title and buttons stay on screen. Drag it by its background or the handle at the top (OB-30, OB-31).
- Choose your modules: one row per module with two or three sentences about what it does (OB-33).

## [1.0.0] - 2026-11-25

### Added

- First-launch tour in the notch: nine short steps that practise opening, closing and switching on the real notch, pick the modules, show what appears beside the closed notch, the power moves, the look and the permissions the chosen modules need. Skip it any time; a tour left half way continues at the next launch (OB-1…OB-25).
- Settings › General › Replay tour starts the tour again at once (OB-5).
- First-use tips: one line at the bottom of a module the first time it opens after the tour, and once a tip about resizing (OB-26…OB-29).

### Changed

- The app is now called Wingmate in Finder, Spotlight, System Settings, the permission prompts and everywhere in its interface. Its bundle id, folders, logs and repository keep the Dynotch name, so permissions and settings stay (WM-1, WM-2).

## [0.113.0] - 2026-11-24

### Added

- Weather: Current location or a saved place; save up to 5 places and tick the one to show, which also stands in when the current location is not known (WX-9).
- Hovering the Tools beside the closed notch shows the tool's controls instead of opening the module: timer Pause/Resume, +1 min, X; stopwatch Start/Pause, Lap, Reset; pomodoro Start/Pause, Next, Reset; Unmute and Keep Awake off; an arrow opens the module. They drop down under the notch, or widen sideways in Wings and with small notices beside the notch (TM-19, TM-20).

### Changed

- A module with tabs keeps one size on every tab: the size of the tab that needs the most room (System | Batteries, Chat | Usage, Calendar | Weather, Notifications with its wide Beeper tab, Tools). A resized size is kept for the whole module, not per tab (RS-7, MG-8).
- The Tools module opens taller, and the pomodoro ring fits the height it gets, so the tab picker no longer slides up (TM-18).
- The stopwatch shows beside the notch by default, also stopped until it is reset (TM-21).

### Fixed

- The weather never loaded: Location Services need their entitlement under the hardened runtime; without a place the tab no longer keeps spinning (WX-10).

## [0.112.0] - 2026-11-24

### Added

- Tools module with Timer | Stopwatch | Pomodoro | Toggles tabs, each switchable in the new Settings › Tools (TM-1, TM-2).
- Timer: preset times, typed times (`12`, `1:30`, `90s`, `1h 15m`), names, up to 5 at once, pause, +1 min; recent custom times (TM-7…TM-9).
- Stopwatch with laps (fastest green, slowest red) and Copy; optional time beside the notch (TM-10…TM-13).
- Pomodoro: Focus, short and long breaks, auto-start options, Shortcuts at focus start and end, today's count and a 7-day chart (TM-14…TM-17).
- The running timer or pomodoro beside the closed notch; one ending within a minute comes right after the meetings; hover opens its tab. End notice with sound; times survive a restart and sleep (TM-3…TM-6).
- Quick toggles: Keep Awake (with lengths), Do Not Disturb (via two Shortcuts), Dark Mode, Mute Microphone, Night Shift, Hide Desktop Icons, Show Hidden Files, Lock Screen; reorderable, each with a global shortcut; muted mic and Keep Awake beside the notch (QT-1…QT-5).
- HUD announcements: charger, Focus, Caps Lock (off by default), Low Power Mode, toggle shortcuts, in the volume HUD's style (HA-1…HA-4).
- Weather tab in the Calendar (Calendar | Weather): now, 24 hours, 7 days, from Open-Meteo with only the rounded place sent; automatic location or a city (WX-1…WX-6).
- Morning forecast at the day's first unlock after a set time, with a rain line (WX-7, WX-8).

## [0.111.0] - 2026-11-24

### Added

- Settings › About: after an update, "Go back to X" installs the version it came from (with the same checks as an update) and turns off automatic updates so it stays; `./scripts/install.sh vX.Y.Z` with an older version also turns them off (RF-21).
- The keyboard lock ends by itself after 3 minutes, or when Esc is held for 3 seconds (RF-4).
- Open, close and module switches show as signposts (category "notch") in Instruments (RF-16).

### Changed

- Haptics play on the trackpad's own motor, so they are felt although Dynotch is never the active app: the three-finger swipe up, every sideways swipe (modules, the module strip, Notifications and Tray tabs, wings), flicking a notice or meeting away, swiping back to the wings and swiping down to open fully. Where the motor is missing the system haptics play as before (H-8).
- Views redraw only when what they show changes: the notch no longer redraws as a whole for every Stats, badge or music update (RF-13); chained animations wait for the previous one to end instead of a fixed time (RF-14).
- Background checks run only while their feature is on, pause while the displays sleep or the Mac is locked, and look three times less often on battery or in Low Power Mode (RF-8…RF-10). The Mission Control watch reads the window list about once a second instead of 3 times a second (RF-7); notifications come from the database's file watch, with a 30 s fallback (RF-12); the menu bar is measured when the app, the display or the badges change (RF-12); clocks that show hours and minutes redraw once a minute (RF-11).
- Replies typed into Google Chat or a linked conversation, and AI answers pasted into an app, are marked transient: no clipboard history keeps them, and the whole previous clipboard (images and files too) comes back afterwards (RF-5).
- Replying by typing waits for the conversation's field, not a fixed 2.5 s; the Google Chat jump waits for its window and checks the conversation as soon as it shows (RF-15).
- Continuing an AI chat in Terminal quotes every part of the command (RF-6).
- CI actions are pinned to commit hashes, and a release without the signing certificate fails instead of building an unsigned app (RF-2, RF-3).
- Housekeeping: unused code removed, one place each for AppleScript, key presses and the clipboard around them, tests grouped by feature, CHANGELOG entries before 0.90 in `docs/CHANGELOG-archive.md` (RF-17…RF-20).

## [0.110.0] - 2026-11-24

### Changed

- Settings › Modules › Swipe-up modules looks like Modules in the strip: one drop-down list with a handle and a switch per module, dragged to reorder; the separate "Add a module" list is gone (QS-18).
- The swipe up itself gives a haptic tick when the row drops down or a quick swipe opens a module (QS-18).
- No name tooltip on the module icons of the top row and the module strip (M-22).
- System: no "System" title; the Options sit beside the System | Batteries tabs, and a sixth Speed tile shows the download and upload speed; the Network tile shows the local IP and the traffic graph (SY-13).

## [0.109.0] - 2026-11-24

### Changed

- Swiping over the module icons no longer builds every module it passes: their last look slides past, and only the module the swipe stops on is built (M-20).
- Swiping over the module icons: with the fingers on the trackpad it steps by the distance moved, the run-out after letting go no longer steps; letting go with a fast flick jumps to the first or last module (M-21).
- Settings › Modules: a hidden module's eye sits left of its switch, so the switches line up; the opened options have a little more room between rows (M-19).

### Fixed

- The Tray no longer stutters: its file list is read in the background and only when something changed, file places and icons are kept instead of being looked up on every redraw (FT-16).
- The notch's top row can no longer slide out of view in any module: a module taller than its room is cut instead of pushing the row up, and no "scroll into view" can move the notch content; a shift that still happens is undone and logged in notch-layout.log (N-26).

## [0.108.0] - 2026-11-24

### Added

- Any module can be hidden from the modules (Settings › Modules › › › "Among the modules"): it keeps running, its notices and menu bar icon still work, and it opens with its shortcut or from the swipe-up row. When the module opened last is hidden, the notch opens on the first listed one (M-18).

## [0.107.0] - 2026-11-24

### Changed

- Google Chat replies are faster: "Sent" shows as soon as the message goes out, arrival is checked in the background (a notice comes if it never shows up), and the web app goes back to Home afterwards (GW-30, GW-31).
- Swiping over the module icons or the calendar's day strip steps one at a time, faster for a stronger flick, instead of jumping to the end (M-17, K-17).
- The swipe-up module switcher always starts on the module opened last, also while it is open, and ticks with haptics as the choice moves (QS-16, QS-17).

### Fixed

- The Calculator no longer slides the notch content up and hides the top row (SZ-18).
- Switching off the AI module is smooth: answers are formatted once and only the visible ones are built, and the keyboard is handed back after the slide (AI-18, N-25).

## [0.106.0] - 2026-11-24

### Changed

- The Join button of a meeting beside the notch (announced, unfolded on hover, Calendar Wings) sits nearest the notch, the first thing the pointer reaches (PV-74).

## [0.105.0] - 2026-11-24

### Changed

- Clicking a chat in an app badge's drop-down opens the notch with that chat's card already open and its reply field ready for typing (B-10f).

## [0.104.0] - 2026-11-24

### Added

- Finished downloads go on top of the tray by themselves and leave it after 3 days; Settings › Tray: "Keep downloads in the tray" and "Downloads leave the tray" (FT-15).
- Clicking a notification card opens its reply field ready for typing, no click into the field needed; a click on a message of the card under the notch does the same (E-27).

### Changed

- Settings › Appearance, under DyNotch Wings: "Small notices beside the notch" switch, in place of the Small notices picker in Notifications; the pop-ups stand beside the notch without the rest of Wings (PV-73).

## [0.103.0] - 2026-11-24

### Added

- Tasks counter drop-down: one small open button (square with an arrow) beside the ×, opening the Tasks module (R-20).

### Changed

- The screenshot mode chooser and the shot pop-up under the notch take the Liquid glass / Black to glass design (SH-16).
- Google Chat replies always go out in the background through the web app; Google Chat no longer comes to the front. If it can't be done, the text is copied (GW-29).

### Fixed

- Calculator: the panel's top row no longer slides out of view when it opens or while typing (SZ-17).

## [0.102.0] - 2026-11-24

### Added

- The swipe-up row takes modules that are off too: picked, the module opens and runs while the notch is open (QS-15).

### Changed

- System opens on its System tab, AI on Chat; a tab picked by hand stays until the next pick, across restarts, as do the Clipboard and Tray tabs (MG-10).
- Animations are faster again: 0.23 s and 0.13 s (D-22).

### Fixed

- No scroll arrow in the iPad menu, which slid it down on hover (TB-11).
- Focus follows the mouse off the open notch in modules that do not type (e.g. System) too (F-18).
- The Calendar opens without a jerk: the day strip and the events are in place from the first frame (K-16).

## [0.101.0] - 2026-11-24

### Added

- Google Chat: *Mark as read* (check button) on the Google Chat cards, read in the web app in the background (GW-28).
- Notifications: during a macOS Focus the notch shows no new notifications again; *Allow during Focus* per source lets an app through (E-20d).

### Changed

- The iPad menu opens right below its button, centred (TB-9).
- No notch on an iPad used as a display (TB-10).
- Every module's empty state uses the same 13 pt text as the AI's *Ask … anything* (D-20).
- The base animation tempo is faster again: 0.27 s and 0.15 s (D-21).

### Fixed

- Pinned Google Chat conversations show the sender, not "Pinned conversation" (GW-27).
- No green "+" beside the pointer while dragging rows in the settings (M-16).
- With the notch open, focus follows the mouse to another app without a click (F-17).

## [0.100.0] - 2026-11-24

### Added

- Menu bar spaces: *Dot*, *Dots* and *Double line* styles, and *Hide when alone*: the space shows only while a menu bar icon stands left of it (MB-13, MB-14).
- Beeper: *Mark as read* on the unread chat cards, in the chat header and by right-clicking a chat in the list (BP-20).
- Settings open on the page you opened last (SD-15).

### Changed

- *Liquid glass* looks like the glass part of *Black to glass* again; three designs: Black, Liquid glass, Black to glass (D-14f).
- The module switcher (now *Swipe-up modules*) and the *Module strip* settings moved to *Settings › Modules* (QS-13, QS-14).
- One tempo for every animation: the notch opens ~15% faster and everything else follows it; the Calendar's large view opens smoothly (D-19).

### Removed

- Focus-based silencing of notifications and badges, with its settings (E-20c).

### Fixed

- *Clipboard › Saved*: reordering no longer stutters or gets stuck (CB-9).
- *Settings › Modules*: rows can be dragged to reorder again (M-15).

## [0.99.0] - 2026-11-24

### Added

- *Settings › Appearance › Accent strength*: how strong the accent colour in the glass is (D-17f).
- *Clipboard › Saved*: drag the rows to reorder them; ⌥⇧V shows them in the same order (CB-8).

### Changed

- The *Original* look is gone; the refined look is the only one (D-14e).
- The iPad button looks and hovers like the buttons beside it; its menu keeps *Mirror or extend to*, *Link keyboard and mouse to* and *Display Settings…* (TB-8).
- Hover highlights are rounder: a capsule on icon buttons, a softer curve on rows (D-15j).
- Module swipe is less sensitive and smoother on long swipes (M-14).

### Fixed

- *Black to glass*: the accent colour now really shows in the glass (D-17e).
- Settings lists: a dragged row no longer stays grey or flies back after it is let go (SD-14).

## [0.98.0] - 2026-11-24

### Fixed

- *Black to glass*: the accent colour now shows in the glass (D-17d).

## [0.97.0] - 2026-11-24

### Added

- *App badges › Add an app*: each app has an icon picker; *Add* adds it with the chosen icon, *Choose image…* adds it with your image (B-13).

### Changed

- *App badges*: the icon picker is a framed button with a small arrow; it opens a panel with the app icon, the preset icons as a grid (the brand marks too) and *Choose image…* (SD-11).
- *Notifications* and *Chats* sources: the switch stands at the row's edge, the "own rules" mark and the rules arrow before it (SD-12).
- Batteries is always a tab of System and AI Usage always a tab of AI; they no longer appear in *Settings › Modules* (MG-9).
- *Screenshots* modes: no order number; the switch stands at the row's edge (SD-13).

### Fixed

- *Accent colour in the glass* uses the accent colour set in macOS (*System Settings › Appearance*), not always blue, and follows a change at once (D-17b). With the Black design its switch is inactive and shown off (D-17c).
- Black to glass: with *Accent colour in the glass* off, the glass no longer turns as black as the top, so the fade from black to glass shows again (D-18b).

## [0.96.0] - 2026-11-23

### Added

- Trial: *Settings › Appearance › Accent colour in the glass* (on by default) mixes a touch of the system accent colour into the glass's dark tint, so Liquid glass and Black to glass look less grey (D-17).
- Trial: *Settings › Appearance › Crisp look* (on by default): the glass is clearer and tinted deeper over a full background blur, grey fills on cards and rows are lighter and the text is brighter, so the notch looks less grey while staying monochrome (D-18).

### Fixed

- Settings: the switches of *App badges*, *Notifications* sources and *Screenshots* modes stand in one column again; a badge's own icon, the "own rules" mark or the order number no longer pushes them sideways. A hidden badge shows its time beside the name and comes back with the eye button (SD-10).

## [0.95.0] - 2026-11-23

### Changed

- Module switcher: the swipe-up row shows the modules you choose in *Settings › Switcher › In the swipe row* (drag to reorder, − to remove, add from *Add a module*), no longer the ones with a shortcut; after updating it starts with those. The row keeps your order and starts on the module opened last; it always stays in one row, the drop-down widens for more modules (QS-10…QS-12).
- Settings look the same everywhere: *App badges* is a grouped form like the other pages, its apps look like the apps under *Notifications*. Long lists (*Notifications › Apps* and *Websites*, *App badges › Add an app*, *Switcher › Add a module*) are closed until opened and have their own search inside (SD-1…SD-4).

## [0.94.0] - 2026-11-23

### Added

- Smart opening: for 5 minutes after a notification (1–15, *Settings › Appearance › Smart opening*), every opening by hover shows its module: Notifications on the Beeper, Google Chat or All tab, Batteries for a device, Tray for a download, Calendar for a meeting announcement (not the AI's notices). Only a meeting in progress comes before it; deleting the notification ends it (SO-9, SO-10).
- Module switcher: a three-finger swipe up shows the modules that have a shortcut, the last opened first; swipe sideways to pick, lift to open it like its shortcut, swipe back down to cancel; a quick swipe opens the last module at once. On by default, 3 or 4 fingers in *Settings › Switcher › Modules*. macOS's Mission Control swipe must be set to four fingers or off (QS-1…QS-9).

## [0.93.0] - 2026-11-23

### Fixed

- Google Chat: a Home list row with only "1 notification" (old spaces keep it after reading) no longer counts as unread, so the badge no longer stays at 3 with nothing unread (GW-26).
- Google Chat: an unread conversation gets its card unless a notification belongs to that conversation alone; when one still gets no card, the log says why (GW-25).
- The notification list's header counts the open tab's notifications, not every tab's (UM-11).

## [0.92.0] - 2026-11-23

### Changed
- Google Chat reads the Safari web app's Home list: the badge counts its unread messages, and the badge's hover list and the cards show each unread conversation's last message with its sender (GW-21, GW-22, GW-23).
- Settings › Google Chat says whether message text can be read; it can't while the web app's window is minimized to the Dock (GW-24).
- Gmail via Apple Mail can count only Gmail's Primary tab: with a Gmail filter that labels category:primary mail "Primary", only the Inbox mail with that label counts (GM-16).

## [0.91.0] - 2026-11-23

### Changed
- A highlighted Google Chat network's badge shows the same white Google Chat mark as the Google Chat web app's badge (BP-19).
- A two-finger swipe over the tasks counter's drop-down switches between its lists (R-19).

### Fixed
- A long swipe over the module icons stops at the first or last module instead of bouncing on with the momentum (M-13).
- Google Chat chats in Beeper no longer show the organisation's network bot (e.g. "Agora Software") in their name; such chats count as one-to-one (BP-18).

## [0.90.0] - 2026-11-23

### Added
- Terminal module: your login shell in the notch, as in Terminal (xterm-256color, full-screen programs, mouse, ⌘C/⌘V/⌘A/⌘K, ⌘+/⌘−/⌘0 font size). Shells keep running while the notch is closed; tabs (⌘T, ⌘W, ⌘1…⌘9), "Open in Terminal" in the tab's folder, dropped files paste their quoted paths, and typing keeps the notch open for 10 s (TE-1…TE-9).

### Changed
- A two-finger swipe over the module icons in the open panel switches modules, as many as the swipe's length and momentum reach (M-12).
- Coming from a badge or counter beside the notch, the notch opens only after the pointer rests on it for 0.6 s (N-24).
- App icons of badges and notifications are black and white (B-12, E-26).
- Every network connected in Beeper (e.g. Telegram, Google Chat) can be highlighted, even without a recent chat (BP-17).
- Linking the keyboard and mouse to an iPad happens in the background without bringing System Settings forward; a linked iPad is ticked and unlinks the same way (TB-7).

### Fixed
- The switcher's swipe counts only fingers really on the trackpad: lifting fingers no longer cancel the switch, a resting thumb no longer opens it, and sideways drift no longer cancels it (AS-21).
- The tasks counter's list picker shows whenever open tasks are in several lists, not only when today's are (R-18).

Older versions (0.89 and before): [docs/CHANGELOG-archive.md](docs/CHANGELOG-archive.md).
