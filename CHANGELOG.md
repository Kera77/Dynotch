# Changelog

## [Unreleased]

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

## [0.89.0] - 2026-11-23

### Added
- Beeper networks can be highlighted (Settings › Notifications › Beeper › Highlighted networks): each gets its own badge beside the notch and its own tab under Notifications, and is taken out of Beeper's badge and tabs (BP-13…BP-16).
- iPad menu: "Link keyboard and mouse to" chooses the iPad in the Displays settings' "+" menu through Accessibility (Universal Control), then closes System Settings (TB-6).

### Changed
- Tasks counter drop-down: no Open button; with tasks in several lists the header switches between them side by side, starting with the list due soonest; the drop-down takes the Liquid glass / Black to glass design (R-17).
- Volume and brightness: the level shows as the AI session does in the wings (percentage and a small white ring); the ring fills as the HUD opens and empties as it closes (H-3c).
- Only the default browser's notifications are watched; the same message open in another browser no longer comes twice. Web apps still pass (E-2g).
- Gmail and Google Chat badges read the default browser's tabs instead of always Ardia's (Chrome, Arc, Brave, Edge, Vivaldi, Safari; Zen and Firefox keep the Dock badge) (B-2c).

### Fixed
- The month name under the calendar's day strip no longer has a black background (K-15b).

## [0.88.0] - 2026-11-23

### Fixed
- Focus follows the mouse back from Ardia's mini window (a large floating window) to Ardia's normal window (F-14c).

## [0.87.0] - 2026-11-23

### Changed
- Gmail and Google Chat badges count the unread number in the titles of their Ardia tabs, read every few seconds while Ardia runs; the Dock badge of a quit web app kept its old number (B-2b).

### Fixed
- Focus follows the mouse onto large floating windows of the same app too, e.g. Ardia's mini window (F-14b).

## [0.86.0] - 2026-11-23

### Added
- Ardia browser: its Gmail, Google Chat and website notifications are handled like Zen's (web app attribution, website sources, typed replies); its alert-style helper counts as Ardia, its installed web apps as web apps (E-2e).
- Web pages open in the browser in use (frontmost, else the last active one still running, else the default): meeting Join, Gmail without its web app, website sources, Google Chat replies, Beeper links (E-2f).

## [0.85.0] - 2026-11-20

### Changed
- Apple Mail as Gmail source: the unread messages now come from Mail's own index (read only, with the existing Full Disk Access); Mail is asked only for its accounts, so a huge Inbox no longer keeps it busy (GM-13).
- After Mail doesn't answer, Dynotch asks again only after 1, 2, 5, then 15 minutes, and it no longer restarts Mail after it was quit (GM-14, GM-15).

### Fixed
- Apple Mail kept freezing ("not responding"): the old read filtered the whole Inbox through Apple Events every minute (GM-13).
- Skipping a track from the dropped-down player no longer brings up the track announcement, which closed the player (MU-10).

## [0.84.0] - 2026-11-20

### Changed
- With small notices dropping down, the Wings open only after the pointer rests on the notch for a moment while a notice hangs under it (PV-71).
- Notifications Wings: clicking Beeper or Google Chat opens its own tab, not All (PV-72).
- No track announcement while the notch is open on Music (MU-10).

## [0.83.0] - 2026-11-20

### Added
- Settings › Notifications › Small notices: Drop down or Beside the notch, with or without Wings (PV-66).
- The announced meeting can stand beside the notch like the other small notices, with Join and an X (PV-67).
- Settings › Screenshots › Show modes after (default 0.15 s): a quick ⌃⇧S takes the first mode without the bar (SH-14).
- Beside the notch, a new track's name stands in the notch's line (PV-68).
- Beside the notch, a hovered meeting countdown or low battery opens to the right instead of dropping down (PV-69).

### Changed
- A click outside the screenshot editor closes it, like Close (SH-15).
- The meeting icon beside the notch never dims (K-8l).
- The recording's dot and time sit left of the notch, which widens to fit the time (SH-5c).
- Under the Wings, the module strip switches only after the Open after delay (MS-9).
- Notifications Wings: the app icons never move; the active app's name stands on the right before its message (PV-70).

### Fixed
- The notch's window no longer keeps catching clicks after a notice or drop-down went away (e.g. Zen's sidebar folders and essentials) (F-16).

## [0.82.0] - 2026-11-20

### Added
- Settings › Notifications › Low battery: choose per device at which level the notch warns (Off, 5–50 %, 20 % by default).

### Changed
- Low battery beside the notch: the level now sits in a red ring filled to the battery's charge.
- Notifications wings: the right side (the text) always fits its content, also while hovering.

### Fixed
- Window switcher: the glass turns grey 0.1 s before the drop-down ends, with no pause in between.

## [0.81.0] - 2026-11-20

### Changed
- The bin icon is gone everywhere: notices beside the notch (also the first "Dynotch updated"), notification groups, "Clear all" and Clipboard items show the usual X.
- Notifications wings: an X at the right edge removes the shown app's notifications from Dynotch.

### Fixed
- Notes wings: while the latest note has not loaded, it is fetched again every second, for at most 10 seconds.
- Window switcher: the glass turns grey as soon as the drop-down ends, without a delay.

## [0.80.0] - 2026-11-20

### Changed
- Wings: the AI usage ring beside the notch (from 70 %) no longer drops down on hover; it widens to the right with the reset time and an X.
- Wings: resting on a module strip icon switches the Wings to that module; a click opens it fully.
- Wings: hovering a file in the Tray wing opens it to the right with its name, like the clipboard items (stays under the pointer, holds for 2 seconds).
- After a notice beside the notch is flicked away (or binned), the icons under the pointer (tasks, badges, AI ring) wait 2 seconds before dropping down.

### Fixed
- Notes wings: the latest note now shows as soon as it has loaded, and a failed load is retried sooner.
- Window switcher: the glass layer and its shadow no longer trail behind the drop-down as a dark ghost on both sides.

## [0.79.0] - 2026-11-20

### Added
- A finished download shows beside the notch: a download icon on the left and a green tick on the right, for 3 seconds; hovering it opens the Tray with the file on top.
- Module strip: a module can also open when the pointer rests on its icon (Settings › Appearance › Module strip, with an adjustable delay).
- Notifications beside the notch: swipe up (or click the small bin) to delete one from Dynotch; the Notification Centre keeps it.

### Changed
- The tasks counter is always white, like the badges; its drop-down shows six tasks and scrolls when there are more.
- The window switcher drops down a little faster.

### Fixed
- The window switcher no longer shows a dark ghost shadow when it drops down from a notch that is wider on one side.
- After swiping to another module in the wings, the right side's text (e.g. Notes) no longer stays empty.

## [0.78.0] - 2026-11-20

### Changed
- DyNotch Wings: while a small notice stands beside the notch, hovering the notch no longer opens the module's wings over it. Swiped up (or closed with X or a click), the notice swims into the notch first, then the module's wings open if the pointer is on the notch, otherwise the notch's own items swim out.
- AI Wings: the logo and name of the AI chosen in the module (Claude or ChatGPT; the chat's AI on the chat tab), and that AI's own session usage on the right.
- Notifications: the All tab and the Notifications wings show everything, Beeper's unread chats too (once, not again as Beeper notifications).
- Clipboard Wings: a hovered dot opens where it is, so a short text no longer pulls the item away from the pointer; an open item also keeps the wings a little below the notch for its two seconds.

### Fixed
- Opening fully from the wings: the open panel's shadow and rim no longer appear at the final size as a grey frame before the module has opened into it.
- Switching modules with a swipe in the wings: the wings always fit the new module ("No new notifications" starts at the notch's edge, Reminders' right side always shows and runs when too long).

## [0.77.0] - 2026-11-19

### Changed
- DyNotch Wings: the small drop-downs (Claude or ChatGPT finished, Claude asks, Dynotch updated, a device connected) stand beside the notch instead of under it: the icon and who it is from on the left, the notice itself on the right.
- DyNotch Wings: a notification beside the notch takes only the room it needs on the left; its text starts at the notch's edge, runs to its end when it does not fit, and starts again when hovered. While the pointer is on it, it stays; the newest one shows after.
- DyNotch Wings: the module strip's icons drop in all at once.
- Tray Wings: just "Drop files" on the left.
- AI Wings: the module's icon and name on the left; the session's percent and its ring (no number inside) on the right.
- Reminders Wings: no Undo button; clicking the ticked ring again unticks it.
- Clipboard Wings: an opened item stays open two more seconds after the pointer leaves it.

### Fixed
- Notifications and Clipboard Wings: hovering another app or a shorter item no longer narrows the wings under the pointer and closes them.
- After a click in the Wings (e.g. ticking a task) the app in front gets the keyboard back; typing no longer beeps.

## [0.76.0] - 2026-11-19

### Changed
- DyNotch Wings: a click on the notch opens the panel fully, a second click on the open panel's notch folds it back into the wings; the wings go when the pointer leaves the notch.
- DyNotch Wings: each side is only as wide as its own content, so the wings no longer take empty room.
- DyNotch Wings: closing, the wings' text slides into the notch at once and only then do the notch's own items (countdowns, badges) swim out; opening fully, the wings' text goes at once too.
- DyNotch Wings: the module strip comes down from above, and sits under anything that hangs below the wings.
- DyNotch Wings, Calendar: always the next event, also on a later day ("Tomorrow", the weekday, or the date).
- DyNotch Wings, AI: the session usage shows even when the AI module's chat tab is the one that opens.
- DyNotch Wings, Stats: four devices next to the notch, always with room for 100%; "+N" opens the others to the left on hover.
- DyNotch Wings, Notifications: the newest app stays next to the notch and open; hovering another opens its name in place, the icons step aside and the message slides the way the pointer moved.
- DyNotch Wings, Reminders: no drop-down list; the newest item at the left, the next due one (or the second newest) at the right, each with a ring in its list's colour. A click ticks it with a few seconds of Undo, then completes it in Reminders and the next one swims out of the notch.
- DyNotch Wings, Notes: the note's name at the left, its text at the right running once to its end; the latest note now loads even before the Notes panel was opened.
- DyNotch Wings, Clipboard: hovering an item opens it as wide as its wing allows, the other two in that wing shrink to dots at the edges.
- DyNotch Wings, Tray: "Drop files on the notch" is the same capsule as AirDrop.

## [0.75.0] - 2026-11-19

### Changed
- The Apple style is now the only look: the Style switch in Settings › Appearance is gone, and the former look's code with it.
- DyNotch Wings spread out of the middle of the notch to the left and right on hover, and slide back in when it closes.
- DyNotch Wings: a two-finger swipe left or right on the wings switches to the next or previous module (round the end); a swipe up over the open panel's top row folds it back into the wings.
- DyNotch Wings: a new notification shows beside the notch (the app and who wrote at the left, the first line at the right) instead of dropping down; a swipe up puts it away, a swipe down opens it.
- DyNotch Wings: files dragged onto the notch no longer open the panel: the wings spread with Keep in Tray at the left and AirDrop at the right; a file kept in the tray shows in the wings.
- DyNotch Wings, AI Usage: the current session on the right as a percentage with a ring in the notch indicator's colours; the weekly limit on the left.
- DyNotch Wings, Stats: the Mac's and the devices' batteries on the left, as many as fit; a button on the right widens the wings to the display's edges to show every device, and they narrow again when the pointer heads back to the notch. Memory and swap stay on the right.
- DyNotch Wings, Notifications: the apps' icons on the left, the newest next to the notch with its name; hovering an icon shows that app's name and latest message, a click opens its notifications.
- DyNotch Wings, Reminders: the task added last on the left; resting on the task icon drops the task list down, as under the notch's task counter.
- DyNotch Wings, Notes: the note changed last, its folder and name on the left, its text on the right.
- DyNotch Wings: text that does not fit runs from right to left, rests at its end and starts again (not with Reduce motion).
- DyNotch Wings, Calculator: the result without the "=" sign.
- DyNotch Wings, Clipboard: the three newest items on the left, the next three on the right; a click copies one.

## [0.74.0] - 2026-11-19

### Changed
- Preview on hover: the notch no longer drops down; it widens to the left and right at its own height (up to two thirds of the display), the module's icon and name on the left, its line on the right. It opens fully only on a click or a two-finger swipe down; the delay and the click toggle are gone.
- Preview on hover with the module strip on: hovering shows the strip under the widened notch straight away.
- The preview is now called DyNotch Wings. The wings are as wide as their content needs, and show each module at a glance: the next event with Join, app icons with counts, the last calculation, the note's first lines, open and overdue reminders with a check-off, the AI limits, Claude's last answer, the batteries, the last copies as chips, the tray's files with AirDrop, the song with play/pause and next, CPU, memory and swap. Only a click on the notch itself opens the panel; the wings' buttons do their own thing.

### Added
- Gmail from Apple Mail (Settings › Notifications › Gmail › Source): every unread message of the chosen Mail accounts, also those that came without a notification, in a new Mail tab and at the top of All, one group per account. The Gmail badge counts them, its hover list shows them, and a click opens the message in Gmail. Mail is only read, nothing is marked read; Mail can be kept running hidden, and its own alerts silenced from a button. The notification-based way stays as the other choice.

## [0.73.0] - 2026-11-19

### Added
- Apple style (Settings › Appearance › Style: Apple / Current, to compare): system text sizes, the accent and system colours, four levels of white, concentric corners, the system's segmented look and empty state, smooth and snappy motion, rolling numbers, hierarchical symbols, hover highlights on buttons; follows Reduce motion, Reduce transparency and Increase contrast.
- Google Chat: your own messages in a card are blue, the other side's stay white.

### Changed
- Google Chat cards load their messages faster: no extra read of the whole page before opening the conversation, and the walk stops at the conversation's link.

## [0.72.0] - 2026-11-19

### Changed
- Recording: nothing drops down under the notch any more; the red dot and the time stay beside it. Hovered, the dot grows into a red circle with a white square (like the iPhone's screen recorder); a click stops the recording.
- Google Chat: a card opened from the notch leaves its conversation read. Marking it unread again is dropped, as the web app opens that menu only in its active window.

### Fixed
- Google Chat cards in the Notifications list show the messages loaded from the web app (the card did not redraw), and keep them after being closed.

## [0.71.0] - 2026-11-19

### Added
- Smart opening: a code just copied (4–8 digits) opens Clipboard with the code outlined; a file just downloaded opens the Tray with the file on top; the first opening of the morning opens Calendar on today. Each can be turned off in Settings › Appearance › Smart opening.
- Screen and area recording: while recording, a line hangs under the notch like a notice, with the time so far on the left and Stop on the right.

### Fixed
- Google Chat cards made from a real notification also open their conversation in the web app when opened, so it is read there (only cards without a notification did before), and a card row appearing closed no longer marks its conversation unread.
- Google Chat cards opened from the notch show the messages again: Dynotch waits until the web app shows the opened conversation (not the previous one) for up to 6 seconds.
- "Mark as unread" after closing a Google Chat card without a reply works: Dynotch waits for the web app's menu (built on its first opening) and presses the item only in the menu it just opened.

## [0.70.0] - 2026-11-19

### Added
- Google Chat cards from the web app: opening one shows its unread messages (read in the web app in the background), with a reply field when the web app can write there, otherwise "Open in Google Chat", which brings the web app forward with that conversation. Closed without a reply, the conversation is marked unread again.
- Menu bar color: an optional middle color for a three-color gradient.
- Switcher: a quick swipe only switches; the switcher drops down after "Show switcher after" (0.15 s by default). Optionally a quick swipe always goes to the previous app.
- Screenshots: Area Recording, a screen recording of a picked area only.
- Settings › Notifications › Dynotch alerts: Low memory and Swap above the limit are separate switches.

### Fixed
- The menu bar color wells open (Solid and Gradient), with ready-made colors and Custom….
- In Notifications a swipe changes the tab only over the tabs; elsewhere it switches modules.
- A memory warning turned off no longer comes back now and then, neither as a pop-up nor as the red dot.

## [0.69.2] - 2026-11-19

### Fixed
- Dynotch could crash while reading the Google Chat web app (its page is deeper than a background thread's stack); the page is now walked without recursion.

## [0.69.1] - 2026-11-19

### Fixed
- Menu bar color now tints the menu bar itself (over it, see-through, so its titles and icons stay visible and clickable) instead of a line under it; the notch stays black. Opacity 10–80%.
- Google Chat cards made from the web app show the conversation's name, not "Olvasatlan" or the person's status, and how many messages are unread.
- Opening such a card reads the conversation in the web app in the background and shows its unread messages.

## [0.69.0] - 2026-11-19

### Added
- Clicking the "Claude finished" line under the notch brings forward the app Claude Code ran in (Terminal, VS Code, the Claude app), with the project's window when its title names it; the line goes.
- "ChatGPT finished": the same line when Codex finishes a turn in the ChatGPT app or the terminal (Settings › General › Tell me when Codex (ChatGPT) finishes; a Stop hook in ~/.codex/hooks.json).
- Colored menu bar: Settings › Menu bar › Menu bar color – solid or gradient, presets, opacity, separate colors for Light and Dark.
- Joining a meeting from its row under the notch folds the row away; the countdown stays.
- Settings › Notifications › Dynotch alerts: turn off Dynotch's own pop-ups by kind (system/swap, AI usage, batteries charged, Dynotch updated).
- Google Chat conversations the web app shows unread without any notification get a card in Notifications.

### Fixed
- The notch no longer disappears when the Dock slides in; only Mission Control hides it.
- Dynotch no longer freezes when a Bluetooth device connects (the banner search runs off the main thread, with short timeouts).
- During a meeting share the notch is left out of the shared picture at once, not only after the next interaction.
- A notification popping up no longer pulls the left badges in or cuts the badge next to the notch.

## [0.68.0] - 2026-11-19

### Added
- Google Chat from its Safari web app (the one added to the Dock), through Accessibility only, no Google Cloud project: a chat you read in Google Chat (or on your phone) leaves the notch within about 10 seconds.
- Replies to Google Chat go straight into the web app's message box in the background, only when it shows the right conversation and an empty box; the reply counts as sent once it appears in the conversation. Otherwise the old typing is used.
- Clicking into a Google Chat card's reply field opens that conversation in the web app in the background, so it is read there too.
- Settings › Notifications › Google Chat: turn reading the web app on or off, how often it is checked (5–30 s), and its status.

## [0.67.3] - 2026-11-19

### Fixed
- Switching from the AI module (or any module with a text field) to another app, e.g. VS Code: the keys go there now; before, the caret blinked but typing went nowhere when macOS already had that app in front.

## [0.67.2] - 2026-11-19

### Fixed
- After a module with a text field was open in the notch, the app in front gets the keyboard back for real, whether the notch closes or you click the app; before, its caret blinked but typing beeped until a click.

### Changed
- Settings › Appearance › Modules in the strip: the rows have more room between them.

## [0.67.1] - 2026-11-19

### Added
- Settings › Appearance › Modules in the strip: drag a row to reorder, like the Modules list.

### Fixed
- Screenshots (whole screen or a selected area) show the notch again; only screen sharing in a browser, Zoom or Teams hides it.
- Notifications module: opens taller still (110 pt over the normal panel) so the tabs, a card and its controls fit.
- After typing in the notch, clicking another app gives it the keyboard right away; before, its caret blinked but the keys went nowhere.
- The refined design's shadow no longer catches clicks meant for the apps around the notch.

## [0.67.0] - 2026-11-19

### Added
- Module strip: drag an icon sideways to reorder the modules; the menu bar, top row and swipes follow the new order.
- Switcher: while swiping, moving the fingers up or down cancels at once, without switching.
- Appearance › Look: Refined (default) or Original. Refined adds a rim light and a soft shadow to the open panel, a black that deepens slightly towards the bottom, liquid glass tinted to the wallpaper's brightness, and an even black-to-glass fade below the top row.

### Changed
- Settings: the new section swims in from below or above, following the direction in the sidebar.
- Notifications module: opens 40 pt taller so the tab picker and a card fit; the picker stays visible when small.
- Tray: a swipe steps between the tabs only with the pointer over them; elsewhere it switches modules.

### Fixed
- Switcher: a 4-finger Space swipe no longer opens the 3-finger switcher.

## [0.66.1] - 2026-11-19

### Changed
- Merged AI: the Chat | Usage tabs sit in the header row beside the Claude | ChatGPT picker, and both tabs open at the medium width so the chat header fits beside the chat list.
- A badge's hover list scrolls without showing a scroll bar.

## [0.66.0] - 2026-11-19

### Added
- Merged modules: *Settings › Modules* can show Batteries as a tab of System ("In System") and AI Usage as a tab of AI ("In AI"). Merged, the module leaves the module row, the strip and the swipes; its alerts, notch indicators, shortcut and size stay as they were, and the host opens on the tab last shown.

## [0.65.1] - 2026-11-19

### Changed
- AI: the sidebar lists only the conversations held in the notch, for Claude and ChatGPT alike; the "On the web" list is gone.
- A badge's hover list holds all its messages (up to 50) and scrolls when there are more than fit.

## [0.65.0] - 2026-11-19

### Changed
- Mission Control: the notch slides up out of the way quickly and slides back down the same way; with the trackpad it leaves as soon as the swipe up starts.
- AI: the history beside the chats no longer lists Claude Code and Codex sessions; under the chats asked in Dynotch, "On the web" lists the claude.ai and chatgpt.com conversations from the browsers' history, opening in the browser.

## [0.64.0] - 2026-11-19

### Added
- Settings › Permissions lists Screen Recording too; a permission that a module in use needs but lacks is flagged orange there and with a dot beside Permissions in the sidebar.
- During a macOS Focus a new app badge does not pulse (same rule as the notification pop-ups).

### Changed
- Less work in the background: full screen, Mission Control, screen sharing and incoming calls share one window list read in the background, instead of five timers asking on the main thread.
- A new badge pulses with a system animation instead of redrawing the notch 20 times a second for five minutes.
- The row beside the notch is redrawn every second only while a meeting, a recording or a hover label counts; otherwise every 15 seconds.
- Spotify is asked every 3 seconds only while its player is on screen; otherwise its own announcements are followed, with a check every 30 seconds.
- One timer watches the clipboard instead of two.
- Typing in the AI chat and its streamed answer no longer redraw the whole notch on every display; neither does the calendar's day view ticking.

### Fixed
- Apple Notes, Messages, Bluetooth and update tools that hang are stopped after a time limit, so a stuck Notes no longer leaves the Notes module dead until Dynotch restarts.
- Log lines written at the same time from different threads are no longer lost; writing the logs never holds up the notch.
- The Notification Center database is read in the background, so a busy database never stalls the notch.

## [0.63.1] - 2026-11-19

### Fixed
- macOS's own Bluetooth banner is looked for in Control Center and the other system processes too, not only in Notification Center; devices.log notes where it was looked for.
- The device notice is centred under the notch.
- Dynotch could freeze with a notice stuck under the notch (e.g. while switching sound devices): measuring the menu bar asked Dynotch's own accessibility from the background.

### Changed
- A device notice can be flicked away upwards; resting on a Bluetooth notice opens the batteries after half a second.

## [0.63.0] - 2026-11-19

### Changed
- Bluetooth devices: the notice shows the device's icon, its name and "Connected"; for AirPods each earbud's and the case's battery on its own line.
- macOS's own Bluetooth banners ("AirPods connected", "Move to iPhone"…) are closed and shown only in the notch; their button becomes the notice's blue button.

### Fixed
- The device notice is taller with room at the bottom, so its text no longer touches the notch's lower edge.
- A Bluetooth device that reconnects every few minutes without going away no longer pops up each time (once in 30 minutes).

## [0.62.1] - 2026-11-19

### Fixed
- Settings › App badges: after Show, the "Hidden until…" line and the Show button go away at once.

## [0.62.0] - 2026-11-19

### Added
- Menu bar spaces: empty gaps or thin lines among the menu bar icons, added in Settings › Menu bar or from a space's menu; ⌘-drag places them.
- App badges can be hidden from the notch for an hour, a day, until a new message, or until shown again; Settings › App badges shows how long and brings them back.

### Fixed
- Gmail and Google Chat (Safari web apps) badges list their messages again: the pages close their own notifications, which Dynotch now keeps, showing as many as the badge counts.

## [0.61.0] - 2026-11-19

### Changed
- Tray: Quick Look needs no click; Space shows the file under the mouse, and an open preview follows the mouse to another file.
- Tray: the Tray and Screenshots tabs' dot colours can be changed too.
- Window switcher drops down from the notch much faster.

### Fixed
- Screenshots are sharp: the whole display is taken in its own pixels and the part is cut out on whole pixels, without resampling.
- Closing the screenshot editor gives the keyboard back to the app used before; typing no longer beeps until a click.

## [0.60.0] - 2026-11-18

### Changed
- Tray tiles: the full name pops up with a spring animation, the icon lifts, and at the left and right edges the name moves inside the tray instead of being cut off.
- Tray folders: the dot colour can be changed from the tab's right-click menu (Colour).

### Fixed
- Screenshot editor: small shots are no longer enlarged and blurred; the picture is shown at most pixel for pixel, on whole pixels.

## [0.59.0] - 2026-11-18

### Changed
- Tray: long file names are shortened in the middle, so their end (a shot's time, the extension) shows; tiles are wider with larger text, and the whole name shows under a tile while the mouse is on it.
- Tray: tiles or list is kept for each tab separately.
- With an icon's details dropped down, passing over a neighbouring icon no longer swaps them; it takes over after resting on it for 0.3 s.

### Fixed
- The screenshot editor test no longer puts its blue test picture on the real clipboard.

## [0.58.0] - 2026-11-18

### Fixed
- The notice under the notch (e.g. "Dynotch updated") has the small X instead of the arrow.
- Submenus in the System options and the music player stay open while choosing.
- Screenshots are taken at the display's full Retina resolution; the pointer is a crosshair
  while picking.
- System counts memory like Activity Monitor (footprint), so Zen's total matches.
- Beeper's badge list shows its unread chats when Beeper has already cleared its notifications.
- The volume keys work with AirPods and other Bluetooth headphones.
- A new track shows its cover and name, not a squeezed player; a long title and artist line
  runs through, then closes a second after its end.
- Opening a row in Settings scrolls it into view.
- Connecting AirPods shows each earbud's and the case's battery with icons; the levels are
  asked for until they arrive, and the sound output notice no longer replaces it.

## [0.57.0] - 2026-11-18

### Added
- Screenshots (Settings › Screenshots): ⌃⇧S, pressed again while holding ⌃⇧, steps through
  Area, Window, Full Screen, Scrolling and Screen Recording (reorderable, each can be turned
  off); letting go takes it. Shots are saved to Pictures › Screenshots and copied; a pop-up
  under the notch opens the editor in a large notch with crop, text, arrow, rectangle, ellipse,
  line, pencil, highlighter, pixelate and numbered steps, colours, widths and undo. Recordings
  can include the Mac's sound and the microphone. The tray has a Screenshots tab with the ten
  newest, which open in the editor.
- Window switcher: "Only covered windows" lists just the windows mostly hidden behind others
  (50% by default, adjustable), with Current Space or All apps.
- System: the closed notch can show CPU, memory and network speed together; each alert can be
  turned off, and a notification comes when swap goes above a chosen size. A warning beside the
  notch can be hidden with its X until it clears.

### Changed
- Reminders: each of the two columns picks what it shows, as in the Reminders app (Upcoming,
  Today, Scheduled, All or any list).
- The level ring (volume, brightness, AI usage) is larger; "100" no longer touches it.
- The Spotify cover sits left of the notch; hovering it drops the player down under the row,
  which stays visible with its badges and counters.
- System: an app's helper processes count as the app (e.g. all of Zen's), busiest first.
- A badge's hover list shows each sender's name once with their messages under it.

### Fixed
- A menu opened from the notch (output, hide, options) no longer closes the notch when the
  pointer moves onto it.

## [0.56.0] - 2026-11-18

### Added
- Music module for Spotify: the cover beside the closed notch with a ring in its colour showing
  the track's progress; hovering it opens the player with seek bar, shuffle, previous, play,
  next, repeat, volume and the Mac's sound output. A new track's name shows for a moment.
- The Music cover hides while paused: by hand until it plays again, or after a pause of a set
  length (5 minutes by default).
- Reminders: an "i" beside a task opens its details as in the Reminders app (title, notes,
  link, date and time, repeat, early alert, list, priority), saved to Reminders.
- Music can stay out of the module list (it then opens from its cover) and its cover can be
  turned off, in Settings › Modules.
- System module: CPU, memory, network, disk and battery tiles, the busiest processes with Quit,
  an optional CPU or network value beside the closed notch, and a red dot when memory runs low,
  the disk fills up or the Mac slows down to cool off.

### Fixed
- Google Chat and other website notifications stay in the notch after the page closes them in
  Notification Center a few seconds later; a message posted again replaces the kept copy.

### Changed
- Reminders are listed newest first by default ("Date Added").
- A notification group shows a bin to remove it and, when open, the small X to close it instead
  of the arrow.

## [0.55.0] - 2026-11-18

### Added
- Hovering an app badge drops down that app's notifications (up to five); a line opens them all
  in the notch.

### Changed
- A click on an app badge opens its notifications in the notch (Beeper's or Google Chat's tab,
  otherwise All with that app's); no right-click action.
- Window switcher: the highlight slides to the next window; the swipe stops at either end, and
  "Distance per window" says how far the fingers move for one window.

### Fixed
- Replying to Google Chat in a space typed the sender and space into the search and sent
  nothing: it now looks up the space, and sends only once the conversation's empty message
  field has the keyboard.

## [0.54.0] - 2026-11-18

### Added
- Window switcher (Settings › Switcher, off by default): the windows drop down from the notch as
  thumbnails, app icons or titles, in three sizes. Current Space or all apps, optionally grouped
  by app, with minimized and hidden ones, or only the display under the pointer; excluded apps.
  Open it with your own shortcut (hold the modifier, the key again or the arrows move, letting go
  switches, or it stays open) or with a three- or four-finger sideways swipe: moving the fingers
  only highlights, lifting them switches, swiping up cancels. W, M, Q and H close, minimize,
  quit or hide. Window previews are a separate switch, as they need Screen Recording.
- Beeper: networks whose app is not installed (e.g. Instagram) get their own icon, fetched once
  from the network's website.
- Banner-free mode: under the Focus named in Settings › Notifications (default "Dynotch")
  Dynotch keeps popping up; a Focus that allows no apps keeps every macOS banner away while the
  notch still shows each notification.

### Fixed
- Google Chat in Zen (and other browsers) replaces its notification for the same chat in place;
  Dynotch missed those and now shows them.
- Previewing a tray file with Quick Look closed the notch (and the preview) when the pointer
  left; the notch now stays while the preview shows, then closes on the next click outside.

## [0.53.0] - 2026-11-18

### Changed
- "Name only" or "With message" for notification pop-ups is set per app (Settings ›
  Notifications › an app's rules); the general switch is gone, the number of lines stays.
- With its chat list closed the Beeper tab is as small as the Google Chat tab.
- A notification pop-up keeps the closed notch's row (badges, countdowns, counters) and drops
  down under it; the badges stay clickable meanwhile.

## [0.52.0] - 2026-11-18

### Added
- Notification pop-ups can show the message, not only the sender: Settings › Notifications ›
  Pop-up shows (and the number of lines), or per app. Messages arriving one after the other
  stack under each other; hovering shows every text in full with the reply field, scrolling
  from the top when long.
- While the screen is shared or recorded (Meet, Zoom, Teams, browsers, macOS recording) the notch
  shows nothing by itself, and its windows are hidden from the share.

### Changed
- Google Chat tab: only the unread messages, like the All tab, without the side list.
- Beeper tab: with the chat list closed it shows the unread chats as cards; opening the list
  slides in the chats and the conversation.

### Fixed
- Switching from the wide Beeper tab to All closed the notch: the smaller panel left the
  pointer outside. The former area now counts until the pointer leaves it.

## [0.51.0] - 2026-11-18

### Added
- Replying to Google Chat from the notch when the notification names no conversation: Dynotch
  opens Google Chat, jumps to the conversation by name (⌘⇧K) and sends only once the window or
  the field shows that name; otherwise the text stays on the clipboard.

### Fixed
- Beeper messages read in Beeper stayed in the notification list.
- Settings › Notifications explains why chats whose banner Dynotch hides cannot disappear once
  read elsewhere, and what to set instead.

## [0.50.0] - 2026-11-18

### Added
- Hovering the tasks counter beside the notch drops down its tasks (up to six), each checked off
  with its circle.

### Changed
- A module opened by its shortcut no longer becomes the one the notch opens on hover.

## [0.49.0] - 2026-11-18

### Added
- Settings › Clipboard: how long ⌥ is held before the items show (default 120 ms, was 250 ms).

### Changed
- ⌥V in the open notch keeps the module: the items drop down under it, and the choice is pasted
  into the module's field.
- Files dragged out of the tray keep their own name, "name (1)" when it is taken; tray files
  are moved out, files of attached folders copied.
- A Beeper chat becomes read only when you click its reply field.
- No unread bubbles on the All tab.
- The tray's chip dot is blue.
- Black design below 100 % is gently see-through with a blur; Liquid Glass blurs more.

### Fixed
- Dropping a file on AirDrop opened no window and left the system's drag stuck (no more Finder
  drags or Space switching).
- After the notch closed, the app in front did not get its key window back (e.g. VS Code did
  not scroll); with focus follows mouse the open notch takes the focus when the pointer returns.
- A reply field kept the notch open until X: now a click elsewhere closes it, while moving the
  pointer away still keeps it.
- Emoji pickers opened by hover now close when the pointer goes elsewhere.
- Swiping in the calendar went past the two weeks.

## [0.48.0] - 2026-11-18

### Changed
- App badges: a left click opens the app (Beeper and Google Chat too); a right click opens its
  notifications in the notch: Beeper's or Google Chat's tab, or All with that app's ones.
- Drop zone: Keep in Tray on the left, AirDrop on the right.
- Settings › Notifications: a browser's sites (Gmail, Google Chat, Google Calendar…) are listed
  under it, each with its own switch.

### Fixed
- The notch stayed over Mission Control: it is now found from the window list too.
- Settings opened over the Beeper or Google Chat tab pushed the top row out of sight.

## [0.47.0] - 2026-11-18

### Changed
- The meeting line under the notch: the time in the calendar's blue, a grey Join button.
- A left click on Google Chat's badge opens the Google Chat tab in the notch (like Beeper's).

### Fixed
- Permissions (Full Disk Access for notifications, Contacts for calls) were lost again and again:
  test builds used the app's own identifier. They have their own now; grant once more and it stays.

## [0.46.0] - 2026-11-18

### Added
- Every module can be resized from its bottom right corner; side lists (notes, chats, the full
  calendar's month) grow with it. The full calendar and the wide chat tabs keep their own size.
- A see-through black panel (opacity below 100 %) blurs what is behind it.

### Fixed
- Focus follows mouse closed drop-downs inside an app (e.g. DataGrip's project picker): inside
  the active app it now moves only between standard windows.
- Settings › Permissions: Grant for Contacts (and Calendar, Reminders) did nothing until Dynotch
  had asked once; it now shows the system's prompt.

## [0.45.0] - 2026-11-18

### Added
- Tasks counter right of the notch: today's reminders, or every open one when none is due today.
  Click opens Reminders; its × hides it for a chosen time (Settings › General › Tasks), or until
  a new task arrives.
- Resize modules like on an iPad: rest the pointer in the bottom right corner and drag the arc;
  ↺ restores the normal size. Kept per module and display; for now the AI module. Can be turned
  off in Settings › Appearance.
- Open panel opacity slider (40–100 %) in Settings › Appearance; the closed notch stays black.
- The tray has its own Settings tab, with a button that shows the tray folder in Finder.
- Calendar: hovering a bar on the day timeline shows the meeting's name and time.

### Changed
- Calendar: the day timeline's bars show only the calendar colour, without the name.
- App badges: background helpers (e.g. AddressBookUrlForwarder) are no longer offered.
- The "swipe up to dismiss" arrow under the notch is smaller and sharper.
- Focus follows mouse follows windows, not apps: another window of the active app (e.g. the
  same browser on two displays) gets the focus too; dialogs, sheets and pop-ups are left alone.

### Fixed
- Clicking the X (or Join) of an announced meeting under the notch clicked the app behind it.

## [0.44.0] - 2026-11-18

### Added
- The notch steps aside during Mission Control, so the Spaces along the top are visible.
- Buttons beside the notch (iPad, focus follows mouse, keyboard lock, pin, settings): reorder
  and hide them in Settings › Appearance, or ⌘-drag them in the notch.
- Calendar: the strip spans two weeks back and ahead; a Today button when another day is
  selected; the month is written small under the days, with a mark where a new month starts.
- Meeting names on the day timeline's bars.
- Settings sections slide in when you switch.

### Changed
- Claude's models show their exact version (Opus 5.5, Sonnet 5.5, Haiku 5.5).

### Fixed
- ChatGPT's icon was missing: the ChatGPT app now has a new identifier.
- The AI module still showed Claude's mark in the module row, the preview, Settings and the
  menu bar.
- The drop zone with AirDrop did not appear when the notch had already opened on hover.

## [0.43.1] - 2026-11-18

### Fixed
- The app could quit when a Bluetooth device connected or disconnected.
- Notifications asked for Full Disk Access although it was granted: local test builds with the
  same identifier could take the switch in System Settings. The notch now says what to do when
  access is on but still denied.

## [0.43.0] - 2026-11-18

### Added
- Calendar: the day as a timeline, with a "now" line; a click on the next meeting joins it.
- Notifications: snooze (in an hour, this evening, tomorrow morning) from the right-click menu;
  no pop-ups while a macOS Focus is on, with an exception per app.
- Calculator: variables (`price = 1200`), `20% of 340`, units (`5 km in mi`, `30 c in f`) and
  `total` for the lines above.
- Notes: the draft is now a Scratchpad; "Paste as Note" adds the clipboard, and any app's
  selected text goes there with Services › New Dynotch Note.
- Reminders: due dates as coloured pills (overdue, today, tomorrow, later).
- Batteries: a week of history per device, with a chart and the estimated time left; a notice
  when a device is charged; a small chart on the low-battery label beside the notch.
- AI: dictation, starred answers under Favorites, and a ChatGPT mode: Codex in the notch or
  chatgpt.com (works with a free account), with "Sign in to ChatGPT…" in Settings.
- Chats tab: unread Beeper chats as notification cards again, with a reply per message and a
  reply field.
- File tray: tiles or a list; the drop area is AirDrop (left third) and Keep in Tray.
- Settings: a sidebar with search, a Permissions tab, and Copy Diagnostics in About.
- Choose which modules the strip under the notch shows; its icons swim out from the pointer.
- Keyboard in the notch: Esc closes, ←/→ change module, ⌘1–⌘9 open one.

### Changed
- The AI module's icon is sparkles; Claude and ChatGPT show their own app icons everywhere, and
  the chat list shows the current service's chats.
- Beeper: reply and reactions in a fixed place beside each message (rows no longer change size
  on hover); clicking a message replies to it; the reaction button opens the emoji picker.
- Network badges are the installed apps' own icons.
- Battery rows use the same text size as the other modules.
- Menu bar panels always use the original dark design, without Liquid Glass.
- One set of colours, motion, tab pickers and empty states across the app; VoiceOver labels on
  icon buttons.
- Faster and lighter: only the visible module is built, new notifications arrive as soon as
  they are written, Beeper is not polled while it is closed, devices are read every five
  minutes, timers may coalesce.

### Fixed
- Content stayed blurry after closing a notification or changing modules.
- Beeper chat pictures were missing in one-to-one chats; without one, a monogram is shown.
- Files dragged out of the tray kept a generated name instead of their own.
- The drop area over the notch did not appear for drags from Finder.
- Pill mode: the expanded top row now sits centred, clear of the corners.
- Calculator: Enter on the last line moved the last result down.
- Full Disk Access: Settings shows a tick when it is granted, and a hint (switch Dynotch off and
  on there) when macOS still denies it after an update.
- ChatGPT's usage header lacked Updated, Show at notch and refresh.
- Clipboard's Keep setting looks like the calendar's lead time.

## [0.42.1] - 2026-11-17

### Fixed
- 0.42 quit right after launch: macOS stops an app that watches Bluetooth devices without saying
  why in its Info.plist. The reason is now there.

## [0.42.0] - 2026-11-17

### Added
- AI module (was Claude): Claude and ChatGPT side by side. ChatGPT runs through Codex in the
  ChatGPT app with the account this Mac is signed in with (subscription or free). Choose the
  service and the model in the header, "Think harder", templates, formatted answers with code
  blocks, Copy and Insert (pastes into the app in front), the clipboard, the selected text or
  files as context, search and pins in the chat list, continue a chat in Terminal. ⌃⌥A asks a
  quick question from anywhere. Default service and models in Settings › General › AI.
- AI usage: Claude | ChatGPT; ChatGPT's limits come from Codex's own logs. The indicator beside
  the notch shows whichever is nearer its limit.
- Clipboard manager: ⌥V pastes the newest item; holding ⌥ shows the items in the notch to choose
  with the arrows; ⌥⇧V for saved items. Texts and images (e.g. Shottr), saved items, search,
  password managers' copies are never kept. Settings › Clipboard.
- File tray: drag files onto the notch to keep them (as references) or send them with AirDrop;
  attached folders as tabs, swipe between them, drag files out, Quick Look with Space, folders
  update by themselves, optional expiry.
- Notifications with tabs: All, Chats, Beeper, Google Chat. Unread Beeper chats stay on top.
- Beeper tab: Beeper's look with the chat list (can be hidden), reactions, replies, reminders,
  open in Beeper with the draft, send files, images and attachments, profile pictures, undo for
  5 seconds, edit and delete; opening a chat marks it read in Beeper too. Only manual sending.
- Google Chat tab without an API, from the notifications still in Notification Center.
- Connected devices: a notice under the notch when Bluetooth or USB devices, displays, drives or
  disk images come or go, with the battery (L / R / Case for AirPods), Eject and Open for drives,
  "Use for audio" for headphones. Settings › General › Connected devices.
- A click on Beeper's badge beside the notch opens the notch on the Beeper tab.
- "Dynotch updated" now pops up under the notch after an update (swipe up to dismiss), besides
  being listed in the notifications.

### Changed
- The highlight of the selected icon in the notch's top row (and of the settings tabs) is a
  capsule, like its background.

### Fixed (reported in 0.41)
- The module strip appeared only on a very thin band: it now uses the lower half of the notch.

### Fixed (reported in 0.40)
- Liquid glass shows only when the notch is fully open; notifications, device notices and the
  preview stay black.
- The pill on displays without a notch ends exactly where the menu bar ends.
- The emoji picker is a small one of Dynotch's own, always under the emoji button.
- The Reminders menu bar count sits exactly between the icon's two lines (drawn into the icon).

## [0.41.0] - 2026-11-17

### Added
- Module strip: rest the pointer on the bottom part of the notch and the modules appear under it
  as see-through blurred circles; click one to open the notch on it. Delay (0.1–1 s) and the
  height of the bottom part (1/8–1/3) are in Settings › Appearance.
- Smart opening: opening by hover shows the module the moment calls for – a meeting starting or
  on, a reminder due within 15 minutes, a calculation just copied (typed into the calculator), a
  low battery, AI usage above 90%. Each event does it once; every rule can be turned off.

## [0.40.0] - 2026-11-17

### Added
- Answer a single line of a notification: the arrow on a line quotes it, the answer appears under
  it and the notch stays open for the next one. Beeper links the answer to that message.
- An emoji button beside the reply field opens the emoji picker; typed emoticons such as :D or :)
  become emoji.
- Settings › Appearance › "Displays without a notch": Notch or Pill.
- The meeting countdown's hover line has a Join button left of the X.

### Changed
- Settings opened in the notch stay until the first click outside instead of pinning it.
- The Reminders menu bar count sits exactly between the icon's two lines.

### Fixed
- Liquid glass turned nearly black in modules that take typing (and after pinning): the glass
  now has a window of its own that never takes the keyboard.
- The first opening after a long idle time lagged: App Nap is off for Dynotch.

## [0.39.0] - 2026-11-17

### Added
- Settings › Appearance with a design choice: Black, Liquid glass, or Black to glass. It applies
  to the open notch, notifications and the menu bar panels; the closed notch stays black.
  Liquid glass needs macOS 26 (a dark blur before).
- The Phone or FaceTime app no longer jumps to the front while a call rings and lasts; it stays
  in the Dock (Settings › General, on by default).

### Changed
- The settings about how Dynotch looks moved from General to the new Appearance tab.

## [0.38.0] - 2026-11-17

### Changed
- Notifications have no reply field by default; turn it on per source (rule "Reply field: Show").

### Fixed
- Focus follows mouse did nothing while macOS drew the pointer in software (e.g. with an iPad as
  a display): the pointer's own window counted as the window under it.

## [0.37.0] - 2026-11-17

### Added
- Settings › General › "Round only the sides with something shown": only a side of the notch
  with something beside it is round.
- The calculator works out lines with words around the calculation ("Asd: 10*10"). Its results
  are blue.

### Changed
- Settings opened in the notch pin it; closing them unpins it again.
- The calculator takes typing as soon as it opens (hover, shortcut or menu bar), on a new line.
- The tablet icon has no arrow any more.

### Fixed
- After typing in the notch, focus follows mouse often did not switch (e.g. between the external
  and the built-in display): the closed notch panel still counted as one taking the keyboard.
- A menu opened in the notch stayed on screen after the notch closed.

## [0.36.1] - 2026-11-17

### Fixed
- Focus follows mouse hardly moved the focus any more: the pause around clicks added in 0.35 is
  undone. The focus log now notes why a switch did not happen.

## [0.36.0] - 2026-11-17

### Added
- A line under the notch when Claude Code asks a question or waits for a permission, in the
  terminal or in VS Code. It goes once answered; hovering it brings that app forward.
  Settings › General › "Tell me when Claude Code asks a question".

## [0.35.0] - 2026-11-17

### Added
- Reminders: a "New task" row at the end of the list adds a task to it with Enter.

### Changed
- The capsule shape is only for the resting notch: when a notification, a call or a line below
  unfolds, or the notch opens, it straightens out and rounds again afterwards.
- The tablet menu moved to the right of the notch, beside "focus follows mouse"; the right-hand
  buttons are a little narrower so all of them fit beside the notch.

### Fixed
- Focus follows mouse could, rarely, stop clicks from working inside an app until it was turned
  off and on: it no longer switches focus during or right after a click.

## [0.34.0] - 2026-11-17

### Added
- A tablet menu left of the feature icons: connect a nearby iPad as an extended display or a
  mirror, switch between the two, disconnect, or open the Displays settings.
- Over a full-screen app the closed notch is hidden, notifications included; moving the pointer
  to the very top edge within the notch's width opens it. Settings › General (on by default).

### Changed
- The rounded notch is a full capsule: its top corners are round too, and it reaches a little
  beyond the physical notch so the rounding shows. It still straightens out as it opens.

## [0.33.0] - 2026-11-17

### Added
- Rounded notch: the closed notch gets round ends like the Dynamic Island, with or without
  anything beside it, and straightens out as it opens. Settings › General (on by default).

### Fixed
- The search field in Settings › Notifications still could not be clicked. It now stands above
  the form and filters both apps and websites; the text fields inside the form take a click too.
- Websites a browser (e.g. Zen) showed notifications for before 0.32 were not split out: their
  notifications still in Notification Center now add them under Settings › Notifications › Websites.

## [0.32.0] - 2026-11-17

### Added
- Notifications a browser (e.g. Zen) shows for websites are split by site: each site is its own
  source under Settings › Notifications › Websites and appears with its first notification.
- Rules per source (app, system notices or website): name, macOS banner (default / hide / show)
  and reply field (automatic / show / hide).
- CLAUDE.md with the project's workflow for future sessions.

## [0.31.0] - 2026-11-17

### Fixed
- The Space switch animation did not show: it unfolded as soon as the fingers lifted, about 0.1 s
  into the swipe. Now the drawing-in always finishes and the notch unfolds while the Spaces slide.
- The search field in Settings › Notifications could not be clicked.

### Added
- App badges no longer cover the menu bar: Dynotch measures where the active app's menus (and
  status items) end left of the notch; badges that do not fit wait behind a "‹ +N" that unfolds
  them on hover.

## [0.30.0] - 2026-11-17

### Changed
- The Space switch animation follows the swipe: the indicators are drawn into the notch as the
  swipe starts and have unfolded by the time the Spaces stop sliding, instead of animating afterwards.

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
