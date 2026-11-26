import Foundation

/// What each module does, in two or three sentences, for the tour's Choose your modules step
/// (spec OB-33). A new `FeatureID` needs its text here; a test checks every listed module.
enum OnboardingModuleTexts {
    static func text(for feature: FeatureID) -> String {
        texts[feature] ?? ""
    }

    private static let texts: [FeatureID: String] = [
        .calendar: "Today's events and the days ahead, with a strip to jump between days. "
            + "Meetings get a Join button and a countdown beside the closed notch before they start.",
        .weather: "Now, the next 24 hours and 7 days, as a tab of the Calendar. "
            + "Use your current location or a saved place; a morning forecast can greet you at the first unlock.",
        .notifications: "Your messages and alerts in one place, grouped by app, also from Beeper, Google Chat, Teams and Mail. "
            + "New ones drop down under the notch, and you can reply or dismiss them right there.",
        .reminders: "Your Apple Reminders as a quick to-do list. "
            + "Add one with New task at the end of a list; times like “tomorrow 9” set the due date.",
        .notes: "Apple Notes in the notch, with formatting and to-do lists. "
            + "Jot something down without switching apps; ⇧⌘L turns lines into a checklist.",
        .calculator: "A calculator that is always one hover away. "
            + "Copy a number anywhere and the notch opens here with it, ready to work with.",
        .clipboard: "A history of everything you copy, text and images, kept across restarts. "
            + "Click an item to paste it back into the app you are in.",
        .tray: "A shelf for files: drop them on the notch to keep them at hand. "
            + "Drag them out again into any app or folder when you need them.",
        .tools: "Timers, a stopwatch with laps and a pomodoro. Quick toggles like Keep Awake sit behind the switch "
            + "button at the top right. "
            + "Running timers stay beside the closed notch, with controls on hover.",
        .terminal: "A real shell inside the notch. "
            + "Run a quick command without opening a Terminal window.",
        .claudeChat: "Ask Claude or ChatGPT without leaving the app you are in. "
            + "The Usage tab shows how much of your Claude limits is left and when they reset.",
        .claudeUsage: "Your Claude usage and when the limits reset, at a glance. "
            + "It lives as the Usage tab of the AI module, and a ring beside the notch warns when you run low. "
            + "Add a second account, like the desktop app's, in Settings › General.",
        .stats: "CPU, memory, disk and network of your Mac at a glance. "
            + "The Batteries tab shows your connected devices and their charge.",
        .battery: "Batteries of your Mac, AirPods, mouse and other connected devices. "
            + "It lives as a tab of System, and warns beside the notch when one runs low.",
        .music: "Play, pause and skip what Spotify plays, with the cover and the track. "
            + "The current track also shows beside the closed notch.",
        .home: "Tiles with what matters from your modules: the next event, the clock, CPU and more. "
            + "Click a tile to open its module, drag it to move it; choose the tiles in Settings › Modules › Home. "
            + "Some tiles work on their own, like the Notepad calculator.",
        .info: "Version, display and notch details of Wingmate. "
            + "Useful for troubleshooting."
    ]
}
