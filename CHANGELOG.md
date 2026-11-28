# Changelog

## [Unreleased]

## [1.10.8] - 2026-11-28

Test build.

### Changed
- Spencer (SL-13): only the layouts made for the displays connected now can be chosen, the others
  are greyed: the one made for exactly these displays (the built-in may be extra for a layout saved
  with the lid closed) or the one remembered for this display setup. A layout remembered for another
  setup stays greyed elsewhere, so *MacBook* (saved by Spencer with the iPad) is greyed beside the
  iPad. When nothing fits, the SL-12 rule applies. Automatic switching picks only a fitting layout.
  What's new entry added.

## [1.10.7] - 2026-11-28

Test build.

### Changed
- Swipe drop-downs (DS-5): the setting is now *Open notifications with a swipe down* and only the
  small notifications under the notch wait for a swipe; the tasks, badges, AI ring and the other
  items beside the notch open on hover again.
- Module icons in the top row (M-24): when they do not fit, a two-finger swipe scrolls the row like
  the buttons on the right; the swipe no longer switches modules. The current module's icon scrolls
  into view by itself. Onboarding's "Click an icon" step says so.
- Focus list (FC-12): every Focus's icon sits in a round badge; the Focus that is on has it in its
  colour with a white symbol, the others grey, as in Control Center.
- Buttons right of the notch (TS-2): no tooltip naming the function on hover.
- Cleaner (TT-32, TT-33): its top-row button rests as grey as the others; *‹ Stats* only shows when
  the Cleaner was opened from the Stats' Disk card. The Stats tip says so.

### Added
- Small notifications (DS-6): a two-finger swipe up (flick up on a Magic Mouse) over a new
  notification, Beeper message or screenshot under the notch puts it away.

### Fixed
- Quick toggles (QT-12): Empty Trash did not empty (Finder's own confirmation cancelled it, -128);
  Finder's warning is off while it empties and restored afterwards.
- Spencer (SL-12): layouts are greyed only when none of their displays is connected, so the current
  one and the ones you can restore are no longer greyed out.
- AI usage drop-down (CS-14): moving from an opened session row to a shorter one no longer shrinks
  the drop-down away from the pointer and closes it; it keeps its height until it closes.
- Focus list (FC-11): the highlight also follows a quick pointer, checked every frame.

## [1.10.6] - 2026-11-28

Test build.

### Fixed
- Focus list (FC-10): the row under the pointer highlights the moment the pointer reaches it. Each
  row follows the pointer itself and switches a highlight layer on screen at once, instead of waiting
  for the menu's late highlight and a redraw; only one row is highlighted at a time.

### Changed
- Focus list (FC-10): a Focus's lengths drop down under it with an animation and fold back up the
  same way when the Focus is clicked again (no animation with Reduce motion).

## [1.10.5] - 2026-11-28

Test build.

### Fixed
- Focus list (FC-9): a highlighted Focus row showed a filled rectangle where its chevron should be;
  the chevron and the tick are now tinted through their own symbol palette.
- Focus list (FC-9): the highlight follows the pointer at once (it follows the menu's own highlight
  instead of a slow tracking area).

### Changed
- Focus list (FC-9): every row (Focuses, lengths, Turn off, Focus Settings…) highlights with a faint
  grey instead of the strong blue.

## [1.10.4] - 2026-11-28

Test build.

### Fixed
- Focus (FC-7): picking a Focus really switches it again. Wingmate handed the keyboard back to the
  app in front while Control Center was open, and that app switch closed Control Center halfway
  ("Control Center switch failed" in `focus.log`). The keyboard now goes back first, and no app
  switch happens (focus follows the mouse included) while the switch runs.
- Focus list icons (FC-6): the Focus rows are drawn by Wingmate, so every Focus shows its coloured
  icon (the menu dropped the images before).

### Changed
- Focus lengths (FC-5): clicking a Focus drops its lengths down under it in the same list, as in
  Control Center, instead of a new menu. Closing the list without a length turns the opened Focus on
  until it is turned off.
- Focus button (FC-8): it moves like the other buttons beside the notch (⌘-drag, or the list in the
  settings); only Settings stays at the end of a scrolling row. Tour text updated.
- Timed pop-ups (E-36): notifications, device and screenshot pop-ups and timed notices stay while the
  pointer is on them, and go at the earliest 3 s after it left.

### Added
- "Claude finished" (CN-10): a two-finger swipe down shows the task (the session's last prompt) and
  the first line of the answer under it; a swipe up folds it, another one puts the notice away.

## [1.10.3] - 2026-11-28

Test build.

### Fixed
- Focus (FC-3): Control Center no longer flashes open when a Focus is picked, turned on or off, or
  when the list is read: Wingmate moves its window off the screen the moment it opens, and closes it
  with its menu bar item if Escape does not.
- Focus icon beside the notch (FC-4): with *Open drop-downs with a swipe down* on, hovering it still
  drops down the name, time left and *Turn off*; a click on the icon turns the Focus off. Tour text
  updated.
- Focus icons (FC-1): a symbol named by the Focus files that other apps cannot draw is replaced by
  one matching the Focus, so every Focus has an icon in the list, on the button and beside the notch.
  The file's symbol names go to `focus.log`.

## [1.10.2] - 2026-11-28

### Changed
- Focus picker (FC-1…FC-3): switches through macOS's Control Center instead of Shortcuts, so no setup
  is needed and the "set a Shortcut" rows are gone. The list is exactly Control Center's Focuses, in
  its order, with their coloured icons; a click drops down Control Center's lengths (For 1 hour,
  Until this evening / tomorrow morning, Until the end of this event, Until I turn it off). macOS
  ends the length itself; the time left comes from Control Center. The Focus Shortcuts settings are
  removed; the tour text is updated.
- Swipe drop-downs (DS-4): with the setting on, the small notifications under the notch (new
  notification, Beeper message, the screenshot pop-up) no longer open on hover; a swipe down opens the
  card or the screenshot editor. Also in Wings mode. Badges and indicators are unchanged.

## [1.10.1] - 2026-11-28

Test build.

### Added
- Focus picker in the top row, next to Settings: every macOS Focus; clicking one drops down
  *For 1 hour*, *For 2 hours*, *Until tomorrow morning* (7:00). The active Focus's icon stands
  beside the closed notch; hovering it shows the time left and *Turn off*. Switching runs the
  Shortcuts chosen in *Settings › General › Focus*, since macOS lets no app switch a Focus; the
  end is Wingmate's own timer (FC-1…FC-4).
- *Open drop-downs with a swipe down* (Settings › General, off by default): the tasks, badges, AI
  ring and other items beside the closed notch no longer open on hover, only with a two-finger
  swipe down (a flick on a Magic Mouse); a swipe up closes them (DS-1…DS-3).
- Trackpad edge sliders (Settings › General › Trackpad, off by default): left edge volume, right
  edge display brightness, top edge keyboard backlight, shown in the HUD with Apple's keyboard
  light icon. *macOS steps* (16, a haptic tap each) or *1% steps* (precise, no haptics) (ES-1…ES-5).

### Changed
- The buttons right of the notch scroll sideways when they don't fit; Focus and Settings stay at
  the right end (TS-1).
- Onboarding: the last tour step mentions the Focus button.

## [1.10.0] - 2026-11-28

Public release: everything from the 1.9.1…1.9.5 test builds. Dynotch is now called **Wingmate**.

### Changed
- The app is called **Wingmate** everywhere (formerly Dynotch): app and bundle
  (`com.peterkereki.Wingmate`), `wingmate://` links, log and Application Support folders, keychain
  items, hooks, release files, GitHub repository, Homebrew cask, docs and the whole history (RN-1).
  Onboarding and tips already used the app name only through the shared texts, so they changed
  with it.
- Updates: a release may carry the app under its new name (`Wingmate-X.Y.Z.zip` with
  `Wingmate.app`). It is accepted when it has the same certificate, goes beside the old bundle in
  the Applications folder, and the old bundle is removed only once the new one is in place; if
  anything fails, the old app starts again. *Launch at login* is remembered for the new app
  (U-11, U-12).

### Added
- One-time takeover at the first launch: settings, folders (Application Support, logs, web
  sign-ins and cookies, the Claude chat history), the added Claude accounts in the keychain,
  the Claude Code and Codex hooks and *Launch at login* come over from the old name; folders whose
  new name already exists are merged in, the old item winning where both have one; the old app
  goes to the Bin. macOS permissions have to be granted again (RN-2…RN-8).
- Rename bridge: every release also carries `Dynotch-X.Y.Z.zip`, a small app under the old name
  that updaters up to 1.9.1 accept. It installs the Wingmate of the same release, keeps *Launch at
  login*, clears the old "Dynotch" rows in System Settings › Privacy and quits (RN-8…RN-10).
- One-time "Dynotch is now Wingmate" window after the takeover: what happened, the permissions to
  grant again with their buttons, and what macOS may still ask (RN-11).
- Homebrew: the new tap `Kera77/homebrew-wingmate`; the old tap's `dynotch` cask points there
  (`tap_migrations.json`, `cask_renames.json`), so `brew upgrade` moves existing installs (RN-12).
- Switcher: with *Only covered windows* on, a new *Covered by* choice: *Focused app* (default) lists
  only the windows under the app you work in, *Any window* keeps the old behaviour (AS-22).

### Security
- Logs show the home folder as `~`, and the notification log's `site=` field only shows web hosts,
  never an account name or file name (C-7b).
- CI and preflight workflows run with a read-only token; GitHub secret scanning, push protection
  and Dependabot security updates are on.

## [1.9.0] - 2026-11-27

Public release: everything from the 1.8.1…1.8.9 test builds, plus a new Cleaner icon.

### Added
- A two-finger swipe up on the overdue task row under the closed notch hides it for 30 minutes;
  then it comes back while the task is still overdue (R-29).
- Cleaner: the disk bar splits the old "Other" into System, App data and Files, with a hover help
  on every part (TT-24).
- Hovering a Claude Code session in the usage ring's drop-down opens it: the task, the step
  running now and the answer, each labelled (CS-13).
- An overdue task stays under the closed notch in one thin row (the oldest one, "+N" for the
  rest) until completed or dismissed; hovering it drops the tasks counter's list down, where an
  overdue task also has Later (back in an hour) and X (R-26, R-28).
- The tasks counter turns orange an hour before a timed task is due and red while a task is overdue
  (R-27).
- Claude Code sessions show the step they run ("Editing NotchView.swift"), the first line of the
  answer once finished, or the task, read from the session's transcript; at the usage ring with
  the app's icon (CS-11, CS-12).
- Cleaner: a disk bar under the header (apps, caches, leftovers, other, free) (TT-18); an app's
  details slide in from the right as a second column with Quit, Uninstall and its files (TT-19);
  when each app was last opened, and sorting by it (TT-20); a Large files tab with files over
  500 MB in Downloads, Desktop, Documents, Movies and Containers (TT-21).
- Following Claude Code sessions at the AI ring can be turned off in Settings › General › AI usage:
  the sessions in the ring's hover and the drop-down for a new session separately (CS-8).
  Onboarding tip of AI Usage updated.
- The AI usage ring's hover also lists the running Claude Code sessions (project, state, how long;
  up to four, then "+N more"), in Wings mode too (CS-6).
- A new Claude Code session drops the usage and the sessions down under the notch by itself, even
  below 70 %; its X closes it until the next session, and it goes by itself 10 minutes after no
  session runs and nothing happened (CS-7). Onboarding tip of AI Usage, What's new and test list for 1.8.3 updated.
- Cleaner module (TT-1…TT-7): Leftovers lists files of removed apps in `~/Library` (named by an app
  identifier, no app of that vendor on the Mac, never `com.apple.*`), Caches lists app, developer
  (DerivedData, Homebrew, npm, pip) and log caches by size, Apps removes an app with its files
  (Quit first if it runs). Everything goes to the Trash after a confirmation; "Freed …" afterwards.
  Full Disk Access hint, `cleaner.log` with counts only. Home tile, Wings text, onboarding module
  text and first-use tip, What's new and test list for 1.8.2.
- AI › Sessions tab (new module, merged into AI): every Claude Code session in Terminal, VS Code or
  the Claude app, newest on top, with its state (Working, Asks, Needs you, Background task,
  Finished, Ready), how long and the prompt's first line; a click brings its window forward,
  right-click Remove, Clear finished. A Sessions Home tile; Wings text. Fed by new `SessionStart`,
  `UserPromptSubmit`, `Stop`, `SessionEnd` hooks installed with "Tell me when Claude Code asks a
  question" (CS-1…CS-5). The module has a tour description and a first-use tip.
- Answers from the notch: while you are in another app, Claude Code's single question shows its
  options (up to 4) as buttons, and a permission request shows the command with Allow and Deny.
  The hooks wait up to 120 s for the answer; the X, the app coming forward or a timeout lets
  Claude Code ask as usual. With buttons, hovering no longer brings the app forward. New
  `PermissionRequest` hook; `claude-hook.log` notes the kind of answer only (CQ-5…CQ-7).
- Test list for test builds: Settings › Testing shows the version's checklist (Works / Broken, a
  note), Copy report puts it on the clipboard with the last 40 lines of each broken item's log;
  a "Test 1.x.y" notice after What's new opens it. The release skill writes the list into
  `TestPlan` (TL-1…TL-4).

### Changed
- New Cleaner icon everywhere: a filled drive with a small sparkle, matching the other filled
  icons of the top row (TT-31).
- Cleaner: Free always stands last, on the right of the disk bar and its labels (TT-28).
- Cleaner: buttons grow a little on hover instead of the grey highlight (TT-30).
- Cleaner: the disk bar and its labels always run from the largest part to the smallest; labels
  wrap when narrow (TT-23).
- Cleaner: every app row ends in size, arrow and two equal circles, green Open (blue X Quit while
  it runs) and a red bin; a click grows the circle over the other into its labelled button, a
  second click does it. Uninstalling a running app quits it first (TT-25). The app details have
  the same circles; the bin asks in the footer, then quits the app and removes it (TT-26).
- The clean beside the closed notch is a ring like the others: a blue arc with sparkles, then a
  green filled ring with a tick (TT-27).
- Onboarding: the Stats, tasks and sessions tips mention the round buttons, the swipe up and the session hover.
- Cleaner: Uninstall in an app's row asks once in the row and moves the app with all its files to
  the Trash without opening it; a running app has a blue Quit there instead, which quits without
  asking (TT-16, TT-17). Its text is the app's usual size (TT-22).
- The Cleaner is no longer a module of its own: Clean on the Stats' Disk card opens it in place of
  the Stats, with ‹ Stats and a pinch to go back (TT-8). It can also be opened from a Cleaner
  button in the top row (off by default, Settings › General) and from Clean on the Home's Disk and
  Cleaner tiles (TT-9, TT-10). A Cleaner tile placed before has to be added again.
- The Cleaner's tick marks are round (TT-11). While it cleans (moving to the Trash, now off the main
  thread, and the scan after it) the whole Cleaner is covered and can't be clicked (TT-12).
- Closing the notch while it cleans shows the same spinner right of the notch, then a green tick;
  hovering it opens the Cleaner again (TT-13).
- In an app of the Apps tab, a two-finger sideways swipe goes back to the app list instead of
  switching modules (TT-14).
- Opening the month in a task's details scrolls it fully into view (R-25).
- Onboarding: the Cleaner's own module text and tip are gone; the Stats' text and tip mention
  Clean on the Disk card (TT-15).
- A task's date and time in its details are set inside the notch in Wingmate's style: quick
  choices (Today, Tomorrow, Next week; 9:00, 12:00, 18:00), a small month that opens from the
  chosen day, hour : minute with arrows (5-minute steps); Repeat, Early Reminder, List and
  Priority are soft capsules with the same menus (R-24).
- The usage dropped down for a new Claude Code session goes by itself after about 6 seconds (it
  stays while hovered) and can be flicked up like other notices (CS-7b).
- A Beeper chat clicked in the Beeper badge's hover list opens on the Chats tab with its card open
  and ready to type (BP-22).

### Fixed
- Cleaner: a circle opened in an app's details folds back when the details close, instead of
  staying open in the list (TT-29).
- A Claude Code session in the usage ring's drop-down can be clicked: it brings its app forward
  (CS-10).
- The 1×2 Month tile fits its tile like the Ask tile: the month's name beside a grid sized to the
  tile (HT-56).
- Onboarding: the Tasks, Sessions and Stats tips mention the overdue row, what a session is doing,
  clicking a session at the usage ring, Uninstall in the Cleaner's rows and large files.
- The notch no longer closes while a pop-up opened from it (a popover, a date picker's calendar)
  reaches outside it (R-23).
- Claude Code sessions in every app are listed (Claude app, VS Code, Cursor, terminals), not only the
  ones that sent a hook event since Wingmate started: running `claude` processes are found with
  the app they run in and show as Ready until their first hook event (CS-9). A helper's app ID
  (e.g. the Claude app's built-in Claude Code) counts as its app, so the icon and click are right.
- With two notices under the notch, the lower (earlier) one has its own X as well (E-35).
- After sending from a chat card the reply field empties at once instead of selecting the sent
  text, the notch no longer jumps, and the card under the notch keeps its size while the messages
  slide up (E-34).
- Beeper and Google Chat cards no longer vanish a few seconds after clicking into their reply
  field: the card stays until it is closed, another card opens or the notch closes, shows what I
  sent as my own message and takes more messages; a card opened from the notch no longer closes
  after a reply (E-32).
- Chat cards show messages as bubbles: the others' on the left, mine on the right, sliding in from
  their side (E-33).
- Notifications (with their second row) and device notices open only as wide as the closed notch
  when their content fits, and only as much wider as needed (E-31).

### Removed
- The test list of test builds: no Settings › Testing page, no "Test 1.x.y" notice, and the
  `TestPlan` code is gone (TL-5). Onboarding is unaffected.

## [1.8.0] - 2026-11-26

Public release: everything from the 1.7.3…1.7.10 test builds.

### Added
- Spencer button beside the notch (shown while Spencer is installed): its menu lists Spencer's
  layouts; picking one restores it and remembers it for the connected displays. Switch
  automatically (on by default): when the displays change (iPad, two monitors…), a notice under the
  notch says which layout comes, with a Cancel pill whose rim runs out anticlockwise in 10 s; then
  the layout is restored through Spencer's command line tool. Update current layout, Open Spencer.
  `spencer.log` (SL-1…SL-6). The tour's last step mentions the button.
- Appearance › Black notifications under the notch: notifications and device notices stay plain
  black whatever the design (D-28).
- A system warning's drop-down beside the notch (low memory, swap, full disk, heat) lists the five
  apps using the most, by memory (by CPU for heat), each with an X that turns into Quit (SY-14).
- Pinching a panel that opened from a drop-down or badge beside the notch brings that drop-down
  back (e.g. the small task list), held until the pointer moves (N-29).
- Calculator › Notepad tile (2×2): the module's notepad on the Home, type, see results, click to
  copy (HT-47). The Home tip and description mention it.
- Join button for online meetings on the Days tile (HT-46).
- Middle at slider for the Center menu bar gradient (MB-17): sets where the middle colour stands
  (10–90 %); the bar shows the gradient, small marks at the thirds and the half pull the knob onto
  them with a light tap.
- Black over glass design (D-24): the top row is black, the glass starts under it at a sharp line
  with a one-pixel light edge and a short soft shadow. Pickable in Settings › Appearance and in the
  tour's look step.
- Two notifications under the notch (E-28): a new sender's notification goes on top, the earlier
  one stays in a compact row under it with its own time; at most two rows. A sticky notice (Claude
  finished, download, What's new) stands in that row instead of hiding under the notification.
  Hovering a row opens that row's card. The tour's notifications line mentions it.
- Microsoft Teams (web) badge (B-15): Settings › Badges lists it first; counted from the Teams
  tab's "(N)" title or the unread chats; a click brings the Teams tab forward.
- Pinch out (N-28): spreading two fingers opens what the pointer is on, like a click: a drop-down
  beside the closed notch opens its module, a badge its notifications, a peek its card, a Home tile
  its module. Pinching in goes back (N-27, HT-40); one gesture moves only one way. The Home tip and
  the tour's badge line mention it.
- Microsoft Teams from the web Teams, without an API (MT-1…MT-12): Teams kept in a browser window of
  its own is read through Accessibility. A Teams tab under Notifications lists the unread chats
  (@mentions first); a click opens the chat's last messages with a reply field that sends in Teams.
  During a meeting a capsule beside the notch shows the mic and the time; its drop-down has mic,
  camera, hand, share and Leave (asks once more). Settings › Chats › Teams: on/off, a global mute
  shortcut, and a warning when you talk while muted (microphone level only). `teams.log`. The Teams
  tab has its first-use tip; What's new lists it.
- Pinch back to the notch's edge (N-27): a panel opened from the closed notch's edge (a drop-down,
  a badge, a badge list row, a notification peek) closes with a two-finger pinch over it.
- Home tiles (HT-42…HT-45): *Calculator* (2×2) counts on the tile with its own keypad; *Days*
  (5×1) shows the Calendar's day strip and the picked day's first events, a swipe over it steps the
  days. Tiles can be dragged to another place in the notch's Home, with a dashed frame where they
  will land.
- Settings › Modules: an eye button beside each switch shows or hides the module among the modules
  without opening the row (M-23).
- Test builds and public releases (U-6…U-10): versions `1.x.y` with y > 0 are test builds,
  published as GitHub prereleases that only apps with *Settings › About › Beta updates* install;
  `1.x.0` goes out to everyone. About shows "test build" next to such a version.
  `scripts/install.sh` turns beta updates on when it installs a test build. Onboarding unchanged
  (no tour step or tip covers updates).

### Changed
- Device notices (Apple Watch, monitor, AirPods…) under the notch are one row, the size of
  "Claude finished"; only wider when batteries or quick buttons need the room (DV-15).
- Spencer menu starts with Active workspace like Spencer's own menu, with its icons: Restore
  Workspace and Update Workspace › All Spaces / Current Space Only. "Update current layout" moved there;
  "Forget this display setup" is gone (SL-11).
- What's new of a public release goes module by module: one page each with Back, Next, Got it
  on the last page and Skip to leave the rest; it sums up the test builds before it, so 1.8.0
  shows everything since 1.7.2 once (WN-9, WN-10).
- Tour brought up to date: Spread and pinch on the Move between modules step, devices and system
  warnings among the indicators, Teams meeting controls, black notifications under Appearance,
  Teams among the notification sources, Spencer's workspace actions on the last step.
- Spencer button: Spencer's own menu bar bell, grey like the other buttons; layouts whose displays
  are not all connected are greyed out (read-only from Spencer's database); no "Pick a layout"
  line; Update current layout comes before Switch automatically (SL-7, SL-8). The tour's text
  still fits.
- Month and Notepad tiles are 1×2 (one row, two columns) (HT-52, HT-53).
- The day strip's today is large and bright only while picked; otherwise blue but dim (K-21).
- Buttons beside the notch are 24 pt wide so seven fit (SL-1).
- Days tile: five days (today ±2) and the day's first three events with the calendar colour (HT-46).
- Month tile is 2×2 (HT-49).
- Tiles take their module's colours: AI usage blue/orange/red, memory pressure, network ↓ blue ↑
  green, disk, battery green/red, pomodoro, music progress, reminder list colours (HT-50).
- Black over glass: the black is exactly the menu bar's height, the line right under it (D-26).
- The line between two notifications under the notch runs full width like the glass rim, brightest
  at its ends, so it melts into the panel's edge (E-29).
- Notifications and device notices hanging under the notch take the chosen design, their top
  black like the notch (D-25).
- Settings search fields start at the left and fill the row; the hint goes once you click in (SD-20).
- Tasks in the notch: no quick add field; both columns line up side by side, New task adds, the
  options moved to a ••• menu in the bottom bar (R-22). Every due date is white text in a filled
  bubble, Today / Tomorrow / overdue keep their colour in the fill (R-21).
- Onboarding: the Home and Tasks tips and module texts mention dragging tiles and New task.

### Fixed
- The Phone app no longer gets stuck "not responding" after calls: Wingmate hides it at most
  twice a call instead of every second, and no longer walks its windows every second (P-6).
- Switch automatically works without a remembered layout: when the displays change, the layout
  made for exactly these displays is offered with the countdown (e.g. Mac+iPad on connecting the
  iPad, MacBook on disconnecting). No second offer for a layout restored in the last minute
  (SL-9, SL-10).
- The Calendar tile stays inside its tile, with the same gap as the others; a compact month when
  the full one does not fit (HT-54).
- Calendar and Agenda tiles list all of today's remaining events and scroll inside the tile; at
  the end the Home scrolls on (HT-55).
- Two sticky notices (e.g. What's new and Claude finished) stand one under the other; the new
  one no longer covers the earlier one (E-30).
- A pinch out that opens the notch gives one haptic tap, not two (N-30).
- Focus follows the mouse no longer switches to the window behind the notch while the pointer is
  on it (F-19).
- The day strip centres the picked day on the first opening too (K-20).
- Black over glass: module tab pickers no longer touch the line (D-27).
- The Notepad's hint disappears completely with the first keystroke (HT-53).
- Swiping over the calendar's day strip steps the days again (in the merged Calendar | Weather
  module the strip sat below its fixed zone) (K-18).
- The shown day is always in the middle of the day strip, also right after opening the notch (K-19).
- The Weekly and Limits tiles show the weekly usage again (HT-48).
- The Custom… colour panel of the menu bar colour opened behind the notch and the tint; it is now
  in front (MB-16).
- Teams in a background tab showed "No browser window shows Teams" (MT-13): now "Teams is in a
  background tab", with a Move Teams to its own window button; the Teams tab's tip says so.
- Beeper: an answered unread card stays open, with my replies, until another card opens or the
  notch closes (BP-21).
- Google Chat: messages in a group conversation show their sender before the line (GW-32).

## [1.7.2] - 2026-11-26

### Changed

- Settings › Modules › Home: the small Home is centred and five columns wide like the normal panel; a tile lands on the place it is dropped (any of the five in a row), tiles it covers move on, and an empty row below always takes one more. While a tile is over it a faint grid shows the cells and where the tile would go. The Home in the notch is as wide as its widest row, at least three tiles (HT-38, HT-39).
- Dragging a tile out of the small Home no longer turns it or the catalog red: a small red minus follows the pointer, like the green plus when adding (HT-37).
- The Back to Home choice is back (Pinch or Swipe down); every way back shrinks the module into its tile like the ‹ Home button, and the rest of a swipe no longer scrolls the Home (HT-40, HT-41).
- Settings › Menu bar › Color: the Middle color switch is gone; the gradient runs Left to right, Right to left, Top to bottom, Bottom to top or Center, which shows the middle color (MB-15).
- Onboarding: the Home tip names the Back to Home choice and dropping tiles in place.

### Fixed

- The pinch back to the Home works: it is read from the system's gesture events, whichever app is active (HT-40).
- Pill on external displays: badge lists, and everything else dropping down, open like with the Notch style instead of as a capsule cutting their edges; the top corners are as round as the bottom ones (D-23).
- A badge's list takes the Liquid glass and Black to glass design, like the tasks counter's (B-14).

## [1.7.1] - 2026-11-26

### Fixed

- Going back from a module opened from a Home tile: pinch and swipe down over the top row both work now, the pinch also while another app is active; the Back to Home choice is gone. `home.log` notes the opened tile and the way back (HT-12, HT-35, HT-36).

### Changed

- Settings › Modules › Home: the tile editor spans the full settings width; a tile dragged out of the Home shows a red minus and comes off wherever it is dropped; each catalog tile has a grey + (green on hover) that adds it; the module groups fold and stay folded. Scrolling stops when the Home preview reaches the top and scrolls the catalog to its end first, then the settings go on (HT-30…HT-34).
- Settings › Modules remembers which rows are open; Collapse all in the Modules header closes them (SD-19). Onboarding: the Home tip names both back gestures and the + button.

## [1.7.0] - 2026-11-25

### Added

- Home tiles (HT-1…HT-29): the Home shows a grid of tiles from your modules that grows with the panel and scrolls, in six sizes (1×1, 1×2, 2×1, 2×2, 2×3, 3×2). Click a tile and its module grows out of it; pinch with two fingers, or swipe down over the top row (Settings › Modules › Home › Back to Home), or click ‹ Home to shrink it back. 57 tiles across every module: clock and world clock, Today (next event, weather, reminders, each opening its module), a month that pages with a swipe, week, agenda and a large calendar, weather now, hourly, 5 days and rain, unread badges, latest notifications, Mail, reminders with ticks, latest note, to-dos, a quick note field, the calculator's result, AI usage rings and bars, the last chat and an Ask field, Mac and device batteries, clipboard items to copy again, the tray's files, Spotify with play and next, each System reading on its own plus top processes, the Terminal and a Run button for a set command, timer, stopwatch, pomodoro, quick toggles, Keep Awake and the version. Arrange them in Settings › Modules › Home: a small Home to drag tiles in, reorder or remove (×), the tiles by module (drag or double-click to add), the World clock's zone and the Run tile's command, and Reset to default. Files cannot be dropped on tiles (the notch's own drop zone takes them), so there is no AirDrop tile. Onboarding: the Home's description and first-use tip now explain the tiles and the way back.

## [1.6.1] - 2026-11-25

### Fixed

- Swiping over a tab picker steps from the tab now shown, so Tools goes through all its tabs instead of flipping between two; over the Calendar | Weather picker a swipe switches the tabs instead of the days (S-7).
- Quick toggle tiles keep a fixed line for their note, so "Click again to empty", "No disks" or a Keep Awake end no longer push the row down; the Empty Trash confirmation is red (QT-11). Onboarding: tour and tips unchanged (no gesture or setting moved).

## [1.6.0] - 2026-11-25

### Added

- AI usage with several Claude accounts: Settings › General › AI usage accounts › Add account signs in another account (for example the Claude desktop app's) in the browser; Wingmate keeps and renews that sign-in in its own keychain item. The AI Usage view shows the account whose session is growing (Auto) or the one picked by hand, with its name and a green dot while in use. The notch ring follows the account nearest its limit, and its hover lists every account's session by name; alerts carry the account's name. With one account nothing changes (CL-8…CL-15). Onboarding: the AI Usage module text and tip mention the second account.

## [1.5.0] - 2026-11-25

### Changed

- Quick toggles moved out of the Tools module into the top row: the switch button beside Settings shows only the toggle tiles, and a click, a module icon, a swipe or Settings closes them. Switch the button off or move it in Settings › Appearance › Buttons beside the notch; off also stops the toggles' shortcuts and indicators. The muted microphone and Keep Awake indicators open the toggles (QT-6, QT-9, QT-10).
- Toggle tiles: Hide Desktop Icons and Show Hidden Files are gone; new are Hide Dock, Display Sleep, Empty Trash (a second click within 3 seconds empties it) and Eject Disks (QT-7). Drag a tile in the notch to reorder; the order is the same as in Settings › Tools (QT-8). Onboarding: the Tools module text, the last tour step and the removed Toggles tab tip follow this.

- Every module's tab picker can be swiped: with the pointer over the tabs (Tools, Clipboard, merged modules such as System, the AI header…), a two-finger swipe steps the tabs; at either end, or elsewhere in the module, it switches modules. New modules get this without extra code (S-6). Onboarding: the tour's Swipe sideways step mentions the tab rows.

### Fixed

- Finder, Spotlight and Launchpad show the app as Wingmate instead of Wingmate: the plain Info.plist name now matches the file name Wingmate.app, so macOS uses the localized name (WM-3). Onboarding: no tour step or tip names the app file, so none changed.

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

- The app is now called Wingmate in Finder, Spotlight, System Settings, the permission prompts and everywhere in its interface. Its bundle id, folders, logs and repository keep the Wingmate name, so permissions and settings stay (WM-1, WM-2).

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

- Haptics play on the trackpad's own motor, so they are felt although Wingmate is never the active app: the three-finger swipe up, every sideways swipe (modules, the module strip, Notifications and Tray tabs, wings), flicking a notice or meeting away, swiping back to the wings and swiping down to open fully. Where the motor is missing the system haptics play as before (H-8).
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

- Settings › Appearance, under Wingmate Wings: "Small notices beside the notch" switch, in place of the Small notices picker in Notifications; the pop-ups stand beside the notch without the rest of Wings (PV-73).

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
