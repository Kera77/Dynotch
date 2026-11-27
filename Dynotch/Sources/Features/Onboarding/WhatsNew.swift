import Foundation

/// One line of What's new: an icon, a title and one sentence (spec WN-1).
struct WhatsNewItem: Sendable, Hashable {
    let symbol: String
    let title: String
    let text: String
}

/// One module's news in a public release: a page of its own in What's new (spec WN-9).
struct WhatsNewSection: Sendable, Hashable {
    let title: String
    let symbol: String
    let items: [WhatsNewItem]
}

struct WhatsNewRelease: Sendable, Hashable {
    let version: String
    let items: [WhatsNewItem]
    /// A public release (x.y.0) groups its news by module, one page each (spec WN-9, WN-10).
    let sections: [WhatsNewSection]

    init(version: String, items: [WhatsNewItem]) {
        self.version = version
        self.items = items
        sections = []
    }

    init(version: String, sections: [WhatsNewSection]) {
        self.version = version
        items = sections.flatMap(\.items)
        self.sections = sections
    }

    /// Shown page by page with Back, Next and Skip (spec WN-9).
    var isPaged: Bool { !sections.isEmpty }
}

/// What each version brought, newest first (spec WN-4). Every user-visible feature or change
/// gets a short line here in the same change; the CHANGELOG is the long version.
enum WhatsNew {
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.9.2", items: [
            WhatsNewItem(symbol: "arrow.triangle.2.circlepath", title: "Ready for the new name",
                         text: "The next update can bring the app under its new name, with your settings.")
        ]),
        WhatsNewRelease(version: "1.9.1", items: [
            WhatsNewItem(symbol: "rectangle.on.rectangle", title: "Under the focused app",
                         text: "With Only covered windows, the switcher lists the windows under the app you work in."),
            WhatsNewItem(symbol: "lock.shield", title: "Cleaner logs",
                         text: "The logs leave out your user name and account names.")
        ]),
        WhatsNewRelease(version: "1.9.0", sections: publicSections190),
        WhatsNewRelease(version: "1.8.9", items: [
            WhatsNewItem(symbol: "chart.bar.xaxis", title: "Free at the end",
                         text: "The Cleaner's disk bar keeps Free on the right, after the used parts."),
            WhatsNewItem(symbol: "plus.magnifyingglass", title: "Growing buttons",
                         text: "The Cleaner's buttons grow a little under the pointer instead of turning grey.")
        ]),
        WhatsNewRelease(version: "1.8.8", items: [
            WhatsNewItem(symbol: "hand.point.up", title: "Swipe an overdue task away",
                         text: "Swipe the overdue row under the notch up: it hides for 30 minutes, then comes back."),
            WhatsNewItem(symbol: "terminal", title: "More of a session",
                         text: "Rest on a session in the usage ring's list: it opens with its task, current step and answer."),
            WhatsNewItem(symbol: "circle.circle", title: "Round app buttons",
                         text: "Open or Quit and the bin sit as two circles; click one to grow it, again to do it."),
            WhatsNewItem(symbol: "chart.bar.xaxis", title: "Disk bar, largest first",
                         text: "The Cleaner's disk bar runs from the largest part, with System, App data and Files split out."),
            WhatsNewItem(symbol: "sparkles", title: "Cleaning ring",
                         text: "Beside the closed notch the clean runs as a ring like the others and fills green when done.")
        ]),
        WhatsNewRelease(version: "1.8.7", items: [
            WhatsNewItem(symbol: "exclamationmark.circle", title: "Overdue tasks stay",
                         text: "The oldest overdue task waits in a thin row under the notch with +N; hover it for the list."),
            WhatsNewItem(symbol: "checklist", title: "Coloured task counter",
                         text: "The counter turns orange an hour before a task is due and red once one is overdue."),
            WhatsNewItem(symbol: "terminal", title: "What each session is doing",
                         text: "Sessions show their app's icon and the step, the answer or the task; click one to go to it."),
            WhatsNewItem(symbol: "trash", title: "Uninstall in one click",
                         text: "Uninstall in an app's row removes it with its files after one question; Quit is blue."),
            WhatsNewItem(symbol: "sidebar.right", title: "Cleaner, roomier",
                         text: "A disk bar, app details sliding in on the right, last used dates and a Large files tab.")
        ]),
        WhatsNewRelease(version: "1.8.6", items: [
            WhatsNewItem(symbol: CleanerGlyph.symbol, title: "Cleaner on the Stats",
                         text: "Clean on the Disk card or a disk tile opens the Cleaner; ‹ Stats or a pinch brings you back."),
            WhatsNewItem(symbol: "checkmark.circle", title: "Cleaning beside the notch",
                         text: "Close the notch while it cleans: a spinner, then a green tick that opens the Cleaner on hover."),
            WhatsNewItem(symbol: "calendar", title: "Whole month in view",
                         text: "Opening a task's month scrolls the details so the whole calendar shows.")
        ]),
        WhatsNewRelease(version: "1.8.5", items: [
            WhatsNewItem(symbol: "terminal", title: "Sessions from every app",
                         text: "Claude Code sessions in the Claude app, VS Code or any terminal show up, even before they do anything."),
            WhatsNewItem(symbol: "calendar", title: "New date picker for tasks",
                         text: "Set a task's day and time right in the notch: quick choices, a small month and arrows."),
            WhatsNewItem(symbol: "xmark.circle", title: "X on both notices",
                         text: "With two notices under the notch, the lower one has its own X too.")
        ]),
        WhatsNewRelease(version: "1.8.4", items: [
            WhatsNewItem(symbol: "terminal", title: "Session pop-up only flashes",
                         text: "A new Claude Code session shows the usage for a few seconds; flick it up, or turn it off in Settings."),
            WhatsNewItem(symbol: "bubble.left.and.bubble.right", title: "Beeper chats open on Chats",
                         text: "A chat clicked in the Beeper badge's list opens its card on the Chats tab; sending keeps the card steady.")
        ]),
        WhatsNewRelease(version: "1.8.3", items: [
            WhatsNewItem(symbol: "terminal", title: "Sessions at the usage ring",
                         text: "The AI ring's hover lists your Claude Code sessions; a new session drops them down by itself."),
            WhatsNewItem(symbol: "bubble.left.and.bubble.right", title: "Chat cards stay while you reply",
                         text: "Beeper and Google Chat cards stay open until you close them, with your messages on the right.")
        ]),
        WhatsNewRelease(version: "1.8.2", items: [
            WhatsNewItem(symbol: CleanerGlyph.symbol, title: "Cleaner",
                         text: "A new module finds leftovers of removed apps and caches, and uninstalls an app with its files."),
            WhatsNewItem(symbol: "bell.badge", title: "Slimmer notifications",
                         text: "Notifications and device notices open only as wide as the notch when they fit.")
        ]),
        WhatsNewRelease(version: "1.8.1", items: [
            WhatsNewItem(symbol: "terminal", title: "Claude Code sessions",
                         text: "AI › Sessions lists every Claude Code session with what it is doing; click one to jump there."),
            WhatsNewItem(symbol: "hand.tap", title: "Answer from the notch",
                         text: "Claude's questions show their options as buttons, permissions get Allow and Deny.")
        ]),
        WhatsNewRelease(version: "1.8.0", sections: publicSections),
        WhatsNewRelease(version: "1.7.2", items: [
            WhatsNewItem(symbol: "square.grid.3x3", title: "Tiles where you put them",
                         text: "Settings › Modules › Home: drop a tile on any of five places in a row; "
                             + "the Home is as wide as its widest row."),
            WhatsNewItem(symbol: "hand.pinch", title: "Pinch or swipe down",
                         text: "Choose the way back to the Home again; the pinch now works whichever app is active."),
            WhatsNewItem(symbol: "capsule", title: "Pill and badges",
                         text: "On a pill, badge lists drop down whole and take your design, like the tasks."),
            WhatsNewItem(symbol: "paintpalette", title: "Menu bar directions",
                         text: "The gradient runs any way, or through a middle color with Center.")
        ]),
        WhatsNewRelease(version: "1.7.1", items: [
            WhatsNewItem(symbol: "hand.pinch", title: "Back to the Home",
                         text: "Pinch, or swipe down over the top row, both take a module opened from a tile back to the Home."),
            WhatsNewItem(symbol: "square.grid.2x2", title: "Easier tile editing",
                         text: "Settings › Modules › Home: full width, a + on every tile, foldable modules, "
                             + "and the Home stays in view while the tiles scroll."),
            WhatsNewItem(symbol: "chevron.down.square", title: "Settings remember open rows",
                         text: "Settings › Modules keeps the opened modules open; Collapse all closes them.")
        ]),
        WhatsNewRelease(version: "1.7.0", items: [
            WhatsNewItem(symbol: "square.grid.2x2", title: "Home tiles",
                         text: "The Home shows tiles from your modules; click one to open it, pinch to come back. "
                             + "Arrange them in Settings › Modules › Home."),
            WhatsNewItem(symbol: "calendar", title: "Tiles for every module",
                         text: "A month that pages with a swipe, weather, reminders to tick, Spotify, timers, toggles "
                             + "and more, from 1×1 up to 3×2.")
        ]),
        WhatsNewRelease(version: "1.6.1", items: [
            WhatsNewItem(symbol: "hand.draw", title: "Swipe through every tab",
                         text: "Over any tab picker, Calendar | Weather and Tools included, each swipe moves one tab on."),
            WhatsNewItem(symbol: "trash", title: "Steady toggle tiles",
                         text: "A note under a tile no longer pushes the row down; Empty Trash asks again in red.")
        ]),
        WhatsNewRelease(version: "1.6.0", items: [
            WhatsNewItem(symbol: "person.2", title: "Usage of two Claude accounts",
                         text: "Add the desktop app's account in Settings › General; AI Usage shows the one in use, "
                             + "and the notch ring's hover lists both.")
        ]),
        WhatsNewRelease(version: "1.5.0", items: [
            WhatsNewItem(symbol: "switch.2", title: "Quick toggles in the top row",
                         text: "The switch button beside Settings opens just the toggles; drag a tile to reorder them."),
            WhatsNewItem(symbol: "dock.rectangle", title: "New toggles",
                         text: "Hide Dock, Display Sleep, Empty Trash (click twice) and Eject Disks; "
                             + "the desktop icon and hidden file tiles are gone."),
            WhatsNewItem(symbol: "hand.draw", title: "Swipe through any tabs",
                         text: "Point at a module's tab row, like the Tools tabs, and swipe sideways to move between its tabs.")
        ]),
        WhatsNewRelease(version: "1.4.0", items: [
            WhatsNewItem(symbol: "app.badge", title: "A new icon",
                         text: "An open notch on frosted glass, in a light and a dark version that follow your system appearance.")
        ]),
        WhatsNewRelease(version: "1.3.1", items: [
            WhatsNewItem(symbol: "envelope.badge", title: "Gmail Primary count is back",
                         text: "Mail under your Primary label counts again, so the Gmail badge and mail notifications show up."),
            WhatsNewItem(symbol: "rectangle.stack", title: "Swipe up comes first",
                         text: "In Settings › Modules the Swipe up settings now come before the Module strip.")
        ]),
        WhatsNewRelease(version: "1.3.0", items: [
            WhatsNewItem(symbol: "rectangle.bottomhalf.inset.filled", title: "The tour opens from the notch",
                         text: "No separate window: the tour fills the open notch and stays until you finish or skip it."),
            WhatsNewItem(symbol: "lightbulb", title: "Tips for every tab",
                         text: "Each module and each of its tabs shows a short tip the first time, covering what it can do."),
            WhatsNewItem(symbol: "bolt", title: "Faster app lists",
                         text: "The long app lists in Settings › App badges and Notifications open right away."),
            WhatsNewItem(symbol: "magnifyingglass", title: "One kind of search field",
                         text: "Every search field in the settings looks and works the same, with an × to clear it.")
        ]),
        WhatsNewRelease(version: "1.2.0", items: [
            WhatsNewItem(symbol: "sparkles", title: "What's new in the notch",
                         text: "After an update a notice waits under the notch; hover it to read what's new, then Got it."),
            WhatsNewItem(symbol: "rectangle.bottomhalf.inset.filled", title: "The tour hangs under the notch",
                         text: "Its card sits right under the notch and moves down when the notch opens while you practise."),
            WhatsNewItem(symbol: "display", title: "More in the Wings on big displays",
                         text: "On a large monitor the Wings show more: upcoming events, apps, clipboard items, files, devices "
                            + "and the next hours' weather."),
            WhatsNewItem(symbol: "timer", title: "A snugger Tools module",
                         text: "The Tools module is just as tall as the Pomodoro needs, without the empty band at the bottom.")
        ]),
        WhatsNewRelease(version: "1.1.0", items: [
            WhatsNewItem(symbol: "sparkles.rectangle.stack", title: "What's new",
                         text: "After an update, this card shows what arrived since the version you had."),
            WhatsNewItem(symbol: "arrow.up.and.down.and.arrow.left.and.right", title: "A tour that fits",
                         text: "The tour is as big as it needs to be, its buttons stay on screen, and you can drag it anywhere."),
            WhatsNewItem(symbol: "xmark.circle", title: "End tour",
                         text: "Settings › General › End tour stops the tour and the first-use tips in the modules."),
            WhatsNewItem(symbol: "square.grid.2x2", title: "Modules explained",
                         text: "The tour's Choose your modules step tells in a few sentences what each module does.")
        ]),
        WhatsNewRelease(version: "1.0.0", items: [
            WhatsNewItem(symbol: "airplane", title: "Hello, Wingmate",
                         text: "Dynotch is now called Wingmate; your settings and permissions stay."),
            WhatsNewItem(symbol: "graduationcap", title: "A guided tour",
                         text: "A short tour at first launch, with first-use tips in each module; replay it in Settings › General.")
        ])
    ]

    /// The releases after `last` up to `current`, newest first (spec WN-1…WN-3).
    static func due(last: String?, current: String, tourDone: Bool) -> [WhatsNewRelease] {
        // A first install gets the tour instead (spec WN-2).
        guard tourDone else { return [] }
        // Updated from 1.0, before this was kept: only the current version (spec WN-3).
        guard let last else { return releases.filter { $0.version == current } }
        let due = releases.filter {
            UpdateLogic.isNewer($0.version, than: last) && !UpdateLogic.isNewer($0.version, than: current)
        }
        // A public release already sums up the test builds before it (spec WN-9).
        guard let paged = due.firstIndex(where: \.isPaged) else { return due }
        return Array(due[...paged])
    }
}

extension WhatsNew {
    /// What the notch shows after an update, or nil when nothing is due (spec WN-6, WN-8).
    static func card(last: String?, current: String, tourDone: Bool) -> [WhatsNewRelease]? {
        guard tourDone, last != current else { return nil }
        let due = due(last: last, current: current, tourDone: tourDone)
        guard due.isEmpty else { return due }
        // Updated without an entry: only fixes (spec WN-8).
        if let last, UpdateLogic.isNewer(last, than: current) { return nil }
        return [WhatsNewRelease(version: current, items: [fixes])]
    }

    static let fixes = WhatsNewItem(
        symbol: "wrench.and.screwdriver", title: "Fixes and small improvements",
        text: "This version makes Wingmate work better; nothing changes in how you use it."
    )
}

/// The last version whose What's new was seen, in UserDefaults (spec WN-3).
struct WhatsNewProgress {
    static let lastVersionKey = "whatsNew.lastVersion"

    let defaults: UserDefaults

    var lastVersion: String? { defaults.string(forKey: Self.lastVersionKey) }

    func markSeen(_ version: String) {
        defaults.set(version, forKey: Self.lastVersionKey)
    }
}
