# Changelog

## [Unreleased]

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
