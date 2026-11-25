import Foundation

/// The first-use tip of every module, in one place (spec OB-27, OB-29). A new `FeatureID`
/// needs its line here; a test checks that every module has one.
enum OnboardingTips {
    static let resizeID = "resize"
    static let resizeText = "Drag the bottom-right corner to resize a module."

    static func text(for feature: FeatureID) -> String {
        texts[feature] ?? ""
    }

    private static let texts: [FeatureID: String] = [
        .home: "Hover the notch any time; swipe with two fingers for the next module.",
        .calendar: "Click a day in the strip to jump to it; Join opens the meeting link.",
        .notifications: "Swipe a notification up to dismiss it; they are grouped by app.",
        .calculator: "Copy a number anywhere and the notch opens here with it.",
        .notes: "⇧⌘L turns the selected lines into a to-do list.",
        .reminders: "Type and press Return to add; times like “tomorrow 9” work.",
        .claudeUsage: "Your Claude usage and when it resets, at a glance.",
        .claudeChat: "Ask Claude or ChatGPT without leaving the app you are in.",
        .battery: "Connected devices and their batteries show up here by themselves.",
        .clipboard: "Everything you copy lands here; click an item to paste it back.",
        .tray: "Drop files on the notch to keep them here.",
        .info: "Version, display and notch details, for troubleshooting.",
        .music: "Controls what Spotify plays; the track also shows beside the notch.",
        .stats: "CPU, memory, disk and network at a glance.",
        .terminal: "A real shell in the notch.",
        .tools: "Timers keep running beside the closed notch; hover them for controls.",
        .weather: "Pick your current location or a saved place in Settings › Calendar."
    ]
}
