import Foundation

/// The public releases' news, one section per module (spec WN-9, WN-10): everything the test
/// builds since the previous public release brought.
extension WhatsNew {
    /// 1.8.0: what 1.7.3…1.7.11 brought.
    static let publicSections: [WhatsNewSection] = [
        WhatsNewSection(title: "Home tiles", symbol: "square.grid.2x2", items: [
            WhatsNewItem(symbol: "square.grid.3x3", title: "New tiles",
                         text: "A Calculator that counts, a Notepad that calculates, Days with Join, "
                             + "a 1×2 or 2×2 Month and the weekly AI usage."),
            WhatsNewItem(symbol: "hand.draw", title: "Move them in the notch",
                         text: "Drag a tile to move it right in the notch; tiles take their module's colour."),
            WhatsNewItem(symbol: "calendar", title: "Calendar tile",
                         text: "It keeps its place in the grid and its events scroll; at the end the Home scrolls on.")
        ]),
        WhatsNewSection(title: "Gestures", symbol: "hand.pinch", items: [
            WhatsNewItem(symbol: "hand.pinch", title: "Spread to open",
                         text: "Spread two fingers over a badge, a drop-down or a tile to open it."),
            WhatsNewItem(symbol: "arrow.down.right.and.arrow.up.left", title: "Pinch to go back",
                         text: "Pinch to close what a task, badge or notification opened, or to get back to its drop-down."),
            WhatsNewItem(symbol: "hand.tap", title: "Calmer notch",
                         text: "One tap when a pinch opens the notch, and no focus change in the app behind it.")
        ]),
        WhatsNewSection(title: "Notifications", symbol: "bell.badge", items: [
            WhatsNewItem(symbol: "paintbrush", title: "In your design",
                         text: "Messages under the notch take your design, or stay plain black (Settings › Appearance)."),
            WhatsNewItem(symbol: "square.stack", title: "Two at once",
                         text: "A new notice no longer hides the one before: they stand one under the other."),
            WhatsNewItem(symbol: "applewatch", title: "Slim device notices",
                         text: "A connected watch, monitor or headphones shows as one slim row under the notch.")
        ]),
        WhatsNewSection(title: "Teams", symbol: "person.2.wave.2.fill", items: [
            WhatsNewItem(symbol: "bubble.left.and.text.bubble.right", title: "Teams in the notch",
                         text: "Keep the web Teams in a window of its own: unread chats, replies and a Teams (web) badge."),
            WhatsNewItem(symbol: "mic.slash.fill", title: "Teams meetings",
                         text: "Mic, camera, hand and Leave beside the notch, a mute shortcut, and a warning when you talk muted."),
            WhatsNewItem(symbol: "macwindow", title: "From any tab",
                         text: "Teams in a background tab can move to its own window.")
        ]),
        WhatsNewSection(title: "Spencer", symbol: "bell", items: [
            WhatsNewItem(symbol: "rectangle.3.group", title: "Layouts beside the notch",
                         text: "Spencer's bell restores a window layout; layouts for missing displays are greyed out."),
            WhatsNewItem(symbol: "display.2", title: "Switches by itself",
                         text: "Connect or remove a display and the right layout is offered, with 10 seconds to cancel."),
            WhatsNewItem(symbol: "arrow.counterclockwise", title: "Workspace actions",
                         text: "Restore Workspace and Update Workspace at the top of the menu, as in Spencer.")
        ]),
        WhatsNewSection(title: "Look", symbol: "paintpalette", items: [
            WhatsNewItem(symbol: "rectangle.tophalf.filled", title: "Black over glass",
                         text: "A new design: a black top row over the glass, parted by a sharp line."),
            WhatsNewItem(symbol: "slider.horizontal.3", title: "Menu bar colours",
                         text: "In a Center gradient, a slider sets where the middle colour stands.")
        ]),
        WhatsNewSection(title: "Calendar and tasks", symbol: "calendar", items: [
            WhatsNewItem(symbol: "calendar.day.timeline.left", title: "Today in the middle",
                         text: "The day strip centres today from the first opening, and swiping over the days works again."),
            WhatsNewItem(symbol: "checklist", title: "Tasks side by side",
                         text: "Both task lists line up, and every due date sits in a readable bubble.")
        ]),
        WhatsNewSection(title: "Chats and system", symbol: "bubble.left.and.bubble.right", items: [
            WhatsNewItem(symbol: "bubble.left.and.bubble.right", title: "Chats stay open",
                         text: "A Beeper card stays open after you answer; Google Chat groups show who wrote."),
            WhatsNewItem(symbol: "exclamationmark.triangle", title: "Who uses it all",
                         text: "A system warning beside the notch lists the five busiest apps, and you can quit them there.")
        ]),
        WhatsNewSection(title: "Settings and fixes", symbol: "gearshape", items: [
            WhatsNewItem(symbol: "testtube.2", title: "Beta updates",
                         text: "Settings › About: turn it on to get test builds before everyone else."),
            WhatsNewItem(symbol: "eye", title: "One click to hide",
                         text: "Settings › Modules: the eye beside a module shows or hides it; app searches start at the left."),
            WhatsNewItem(symbol: "phone", title: "Phone app fixed",
                         text: "The Phone app no longer gets stuck after a call.")
        ])
    ]

    /// 1.9.0: what 1.8.1…1.8.9 brought, and the new Cleaner icon.
    static let publicSections190: [WhatsNewSection] = [
        WhatsNewSection(title: "Claude Code", symbol: "terminal", items: [
            WhatsNewItem(symbol: "terminal", title: "Sessions at the usage ring",
                         text: "The AI ring's hover lists your Claude Code sessions from every app; click one to jump there."),
            WhatsNewItem(symbol: "text.line.first.and.arrowtriangle.forward", title: "What each one is doing",
                         text: "Each session shows its app's icon and its step, answer or task; rest on it for more."),
            WhatsNewItem(symbol: "hand.tap", title: "Answer from the notch",
                         text: "Claude's questions show their options as buttons, permissions get Allow and Deny.")
        ]),
        WhatsNewSection(title: "Cleaner", symbol: CleanerGlyph.symbol, items: [
            WhatsNewItem(symbol: CleanerGlyph.symbol, title: "A new Cleaner",
                         text: "Clean on the Stats' Disk card finds leftovers of removed apps, caches and large files."),
            WhatsNewItem(symbol: "trash", title: "Uninstall in one click",
                         text: "Two round buttons in an app's row: Open or Quit, and the bin that removes it with its files."),
            WhatsNewItem(symbol: "chart.bar.xaxis", title: "Disk bar",
                         text: "Largest part first, split into System, App data and Files, with Free at the end."),
            WhatsNewItem(symbol: "circle.circle", title: "Cleaning beside the notch",
                         text: "Close the notch while it cleans: a ring runs beside it and fills green when done.")
        ]),
        WhatsNewSection(title: "Tasks", symbol: "checklist", items: [
            WhatsNewItem(symbol: "exclamationmark.circle", title: "Overdue tasks stay",
                         text: "The oldest overdue task waits in a thin row under the notch; swipe it up to hide it for 30 minutes."),
            WhatsNewItem(symbol: "checklist", title: "Coloured counter",
                         text: "The counter turns orange an hour before a task is due and red once one is overdue."),
            WhatsNewItem(symbol: "calendar", title: "New date picker",
                         text: "Set a task's day and time right in the notch; its month shows whole.")
        ]),
        WhatsNewSection(title: "Notifications and chats", symbol: "bell.badge", items: [
            WhatsNewItem(symbol: "bell.badge", title: "Slimmer notifications",
                         text: "Notifications open only as wide as the notch when they fit; both notices have an X."),
            WhatsNewItem(symbol: "bubble.left.and.bubble.right", title: "Chat cards stay",
                         text: "Beeper and Google Chat cards stay open while you reply; Beeper chats open on the Chats tab.")
        ]),
        WhatsNewSection(title: "Look", symbol: "paintpalette", items: [
            WhatsNewItem(symbol: CleanerGlyph.symbol, title: "New Cleaner icon",
                         text: "The Cleaner's button is a drive with a small sparkle, filled like the others."),
            WhatsNewItem(symbol: "plus.magnifyingglass", title: "Growing buttons",
                         text: "The Cleaner's buttons grow a little under the pointer instead of turning grey.")
        ])
    ]
}
