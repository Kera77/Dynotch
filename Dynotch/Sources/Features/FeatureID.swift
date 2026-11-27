import Foundation

/// A function shown in the notch panel's top menu bar.
enum FeatureID: String, CaseIterable, Identifiable, Sendable {
    case home
    case calendar
    case notifications
    case calculator
    case notes
    case reminders
    case claudeUsage
    case claudeChat
    case claudeSessions
    case battery
    case clipboard
    case tray
    case info
    case music
    case stats
    case terminal
    case tools
    case weather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .calculator: "Calculator"
        case .notes: "Notes"
        case .reminders: "Reminders"
        case .claudeUsage: "AI Usage"
        case .claudeChat: "AI"
        case .claudeSessions: "Claude Code sessions"
        case .battery: "Batteries"
        case .clipboard: "Clipboard"
        case .tray: "Tray"
        case .info: "Info"
        case .music: "Music"
        case .stats: "System"
        case .terminal: "Terminal"
        case .tools: "Tools"
        case .weather: "Weather"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house.fill"
        case .calendar: "calendar"
        case .notifications: "bell.fill"
        case .calculator: "plus.forwardslash.minus"
        case .notes: "note.text"
        case .reminders: "checklist"
        case .claudeUsage: "gauge.with.dots.needle.67percent"
        case .claudeChat: "sparkles"
        case .claudeSessions: "terminal"
        case .battery: "battery.75percent"
        case .clipboard: "doc.on.clipboard"
        case .tray: "tray.full"
        case .info: "info.circle.fill"
        case .music: "music.note"
        case .stats: "chart.bar.xaxis"
        case .terminal: "apple.terminal"
        case .tools: "timer"
        case .weather: "cloud.sun.fill"
        }
    }
}

extension FeatureID {
    /// The module this one can be merged into as a tab (spec MG-1).
    var mergeHost: FeatureID? {
        switch self {
        case .battery: .stats
        case .claudeUsage: .claudeChat
        case .claudeSessions: .claudeChat
        // A tab of the calendar (spec WX-1).
        case .weather: .calendar
        default: nil
        }
    }

    /// The name of its tab in a merged module (spec MG-2).
    var tabTitle: String {
        switch self {
        case .claudeChat: "Chat"
        case .claudeUsage: "Usage"
        case .claudeSessions: "Sessions"
        default: title
        }
    }
}

enum NavigationDirection: Equatable, Sendable {
    case next
    case previous
}

extension FeatureID {
    /// The neighbour of `current` in `list`, or nil at either end (no wrap-around, spec S-3).
    static func neighbor(of current: FeatureID, in list: [FeatureID], direction: NavigationDirection) -> FeatureID? {
        guard let index = list.firstIndex(of: current) else { return list.first }
        let target = direction == .next ? index + 1 : index - 1
        return list.indices.contains(target) ? list[target] : nil
    }
}
