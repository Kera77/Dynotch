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
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .calendar: "Naptár"
        case .notifications: "Értesítések"
        case .calculator: "Számológép"
        case .notes: "Jegyzetek"
        case .reminders: "Emlékeztetők"
        case .claudeUsage: "Claude"
        case .info: "Info"
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
        case .info: "info.circle.fill"
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
