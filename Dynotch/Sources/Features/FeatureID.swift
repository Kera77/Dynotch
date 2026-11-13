import Foundation

/// A function shown in the notch panel's top menu bar.
enum FeatureID: String, CaseIterable, Identifiable, Sendable {
    case home
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .info: "Info"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house.fill"
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
