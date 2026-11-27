import Foundation

/// The first-use tip of every module and of every tab, in one place (spec OB-27, OB-29, OB-37):
/// two or three short sentences touching each function. A new `FeatureID` or tab needs its tip
/// here; a test checks that every module and tab has one.
enum OnboardingTips {
    static let resizeID = "resize"
    static let resizeText = "Drag the bottom-right corner to resize a module. The size is kept for next time."

    /// The tabs that get a tip of their own (spec OB-37).
    static let tabs: [FeatureID: [String]] = [
        .notifications: ["all", "chats", "beeper", "network", "googleChat", "teams", "mail"],
        .tools: ToolsTab.allCases.map(\.rawValue),
        .clipboard: ClipboardTab.allCases.map(\.rawValue),
        .tray: ["tray", "screenshots", "folder"]
    ]

    /// A tip's id: the module's, or the module's and its tab's for modules with tabs.
    static func id(for feature: FeatureID, tab: String?) -> String {
        guard tabs[feature] != nil, let tab else { return feature.rawValue }
        return "\(feature.rawValue).\(tab)"
    }

    static func text(forID id: String) -> String {
        texts[id] ?? ""
    }

    /// The notifications tab a tip belongs to; every highlighted network shares one.
    static func tab(_ tab: NotificationsTab) -> String {
        if case .network = tab { return "network" }
        return tab.rawValue
    }

    /// The tray tab a tip belongs to: the tray, the screenshots or an added folder.
    @MainActor static func trayTab(_ folder: UUID?) -> String {
        guard let folder else { return "tray" }
        return folder == TrayStore.screenshotsID ? "screenshots" : "folder"
    }

    private static let texts: [String: String] = [
        "home": "Click a tile (or spread two fingers over it) to open its module; pinch to come back (or swipe down, "
            + "Settings › Modules › Home › Back to Home). Drag a tile to move it, here or in Settings › Modules › Home. "
            + "On the Notepad tile you type calculations as in the Calculator.",
        "calendar": "Click a day in the strip or swipe over it to see that day; Join opens the meeting link. "
            + "The icon at the strip's end opens the month view. Before a meeting a countdown waits beside the "
            + "closed notch; hover it for the name and Join.",
        "weather": "Now, the next 24 hours and the next 7 days. Choose your current location or saved places in "
            + "Settings › Calendar › Weather, where the morning forecast at the first unlock is set too.",
        "notifications.all": "Everything that arrived, grouped by app and sender; click one to open its app. "
            + "Swipe a notification up or click × to dismiss it, right-click to snooze it. Swipe over the tab row to "
            + "switch tabs.",
        "notifications.chats": "Your unread Beeper and Google Chat conversations as cards. Click a card to read it "
            + "and reply right here; the tick marks a Beeper chat as read.",
        "notifications.beeper": "Beeper's chats on the left, the conversation on the right; the sidebar button hides "
            + "the list. Hover a message to react or reply, drop a file to send it, and use the bell for a reminder.",
        "notifications.network": "The unread chats of a highlighted Beeper network, with a reply field on each card. "
            + "Choose which networks get their own tab and badge in Settings › Chats.",
        "notifications.googleChat": "Unread Google Chat messages, read from their notifications. Click a card to read "
            + "it and reply; it stays here until you read it in Google Chat.",
        "notifications.teams": "Unread Teams chats from Teams open in a browser window of its own; @mentions come first. "
            + "Click a chat to read it and reply. During a meeting the mic and the controls sit beside the notch. "
            + "Teams in a background tab? Settings › Chats › Teams moves it to its own window.",
        "notifications.mail": "Unread mail from the inboxes of your Apple Mail accounts, grouped by account. Click a "
            + "message to open it in Gmail or Mail; pick the accounts in Settings › Chats.",
        "calculator": "Type a calculation on each line; the result shows on the right, click it to copy. Variables "
            + "(price = 1200), units (5 km in mi), percentages and total work too.",
        "notes": "Your Apple Notes: pick a folder and a note on the left, or write a draft and save it to Notes. "
            + "Edits save by themselves; ⌘B, ⌘I and the Aa menu format text, ⇧⌘L makes a checklist.",
        "reminders": "Click New task at the end of a list and type: “tomorrow 9” sets the date. Click the "
            + "circle to complete a task, the i for its details; each column's header picks what it shows.",
        "claudeChat": "Ask Claude or ChatGPT; the header picks the provider, the model and a template. Add the "
            + "clipboard, selected text or a file above the field. ⌃⌥A opens it from anywhere, Insert pastes an answer.",
        "claudeUsage": "How much of your Claude or ChatGPT limits is used and when they reset. Show at notch keeps "
            + "the session ring beside the closed notch; above 70% it shows there by itself. With a second account "
            + "(Settings › General › AI usage accounts) Auto shows the one in use, or pick one. Hover the ring to see your "
            + "running Claude Code sessions; a new session drops them down for a few seconds (flick up to hide). "
            + "Both can be turned off in Settings › General › AI usage.",
        "claudeSessions": "Your Claude Code sessions, newest on top: Working, Asks, Finished and how long. Click one to "
            + "bring its window forward; right-click to remove it. Needs Settings › General › Tell me when Claude Code asks.",
        "cleaner": "Leftovers lists files of apps that are gone, Caches what apps keep to load faster, Apps removes an "
            + "app with its files. Tick what to clean and click Clean; everything goes to the Trash, so you can put it back.",
        "stats": "CPU, memory, network, disk and battery, with the busiest processes; click × twice to quit one. "
            + "Options picks what shows beside the closed notch and which warnings you get; "
            + "a warning's drop-down lists the five apps using the most, each with its own quit.",
        "battery": "Your Mac and connected devices with their charge; click one for its week and the time left. "
            + "A low device shows beside the notch; set the limit per device in Settings › Notifications.",
        "music": "Controls Spotify: play, skip, shuffle, repeat, and drag the progress bar. Below are Spotify's "
            + "volume and the Mac's sound output; the eye menu hides the cover beside the notch while paused.",
        "terminal": "A real shell that keeps running when the notch closes. ⌘T opens a tab, ⌘W closes it, and a "
            + "dropped file pastes its path. The header button opens the folder in Terminal.",
        "info": "Version, display and notch details of Wingmate. To report a problem, Settings › About › Copy "
            + "Diagnostics collects what is needed, without any content.",
        "tools.timer": "Click a preset, or type a time like 12, 1:30 or 1h 15m and press Return; a name is optional. "
            + "Up to five timers run at once beside the closed notch; hover one for Pause, +1 min and ×.",
        "tools.stopwatch": "Start, take laps while it runs, reset when stopped. The fastest lap is green, the slowest "
            + "red; Copy puts the laps on the clipboard. It also shows beside the closed notch, with controls on hover.",
        "tools.pomodoro": "Focus and breaks in turns: Start, Skip to the next phase or Reset. The dots show the cycle, "
            + "below are today's sessions and the week. Lengths and Shortcuts to run are in Settings › Tools.",
        "clipboard.history": "Everything you copy, text and images; click an item to paste it, the star saves it. "
            + "⌥V pastes the last copy, hold it to choose one. Apps to skip are in Settings › Clipboard.",
        "clipboard.saved": "The items you starred stay here for good; drag to reorder them or add your own text. "
            + "⌥⇧V opens this list from any app.",
        "tray.tray": "Drop files on the closed notch to keep them here, or on AirDrop to send them. Drag them out into "
            + "any app (⌥ moves), press Space for Quick Look. The + adds a folder as its own tab.",
        "tray.screenshots": "Your latest screenshots; open one to mark it up in the editor, or drag it into any app. "
            + "Right-click the tab to change its colour.",
        "tray.folder": "A folder you added with +, always up to date. Drag files in and out, press Space for Quick Look; "
            + "right-click the tab to change its colour."
    ]
}
