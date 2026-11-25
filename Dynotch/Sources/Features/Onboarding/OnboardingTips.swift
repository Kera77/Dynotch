import Foundation

/// The first-use tip of every module, in one place (spec OB-27, OB-29). A new `FeatureID`
/// needs its line here; the switch has no default, so a missing one does not compile.
enum OnboardingTips {
    static let resizeID = "resize"
    static let resizeText = "Drag the bottom-right corner to resize a module."

    static func text(for feature: FeatureID) -> String {
        switch feature {
        case .home: "Hover the notch any time; swipe with two fingers for the next module."
        case .calendar: "Click a day in the strip to jump to it; Join opens the meeting link."
        case .notifications: "Swipe a notification up to dismiss it; they are grouped by app."
        case .calculator: "Copy a number anywhere and the notch opens here with it."
        case .notes: "⇧⌘L turns the selected lines into a to-do list."
        case .reminders: "Type and press Return to add; times like “tomorrow 9” work."
        case .claudeUsage: "Your Claude usage and when it resets, at a glance."
        case .claudeChat: "Ask Claude or ChatGPT without leaving the app you are in."
        case .battery: "Connected devices and their batteries show up here by themselves."
        case .clipboard: "Everything you copy lands here; click an item to paste it back."
        case .tray: "Drop files on the notch to keep them here."
        case .info: "Version, display and notch details, for troubleshooting."
        case .music: "Controls what Spotify plays; the track also shows beside the notch."
        case .stats: "CPU, memory, disk and network at a glance."
        case .terminal: "A real shell in the notch."
        case .tools: "Timers keep running beside the closed notch; hover them for controls."
        case .weather: "Pick your current location or a saved place in Settings › Calendar."
        }
    }
}
