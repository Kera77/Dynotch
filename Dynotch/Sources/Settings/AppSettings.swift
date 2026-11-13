import Combine
import Foundation

/// User preferences, persisted in UserDefaults (spec G-5).
@MainActor
final class AppSettings: ObservableObject {
    static let closeDelayRange: ClosedRange<Double> = 0...3
    static let defaultCloseDelay = 0.3

    private enum Key {
        static let closeDelay = "closeDelay"
        static let featureOrder = "featureOrder"
        static let enabledFeatures = "enabledFeatures"
        static let lastFeature = "lastFeature"
    }

    private let defaults: UserDefaults

    /// Seconds the panel stays open after the pointer leaves it (spec N-4, N-5).
    @Published var closeDelay: Double {
        didSet {
            let clamped = Self.normalizedDelay(closeDelay)
            if clamped != closeDelay { closeDelay = clamped; return }
            defaults.set(closeDelay, forKey: Key.closeDelay)
        }
    }

    /// Order of features in the menu bar, including disabled ones (spec M-3).
    @Published var featureOrder: [FeatureID] {
        didSet { defaults.set(featureOrder.map(\.rawValue), forKey: Key.featureOrder) }
    }

    @Published private(set) var enabledFeatures: Set<FeatureID> {
        didSet { defaults.set(enabledFeatures.map(\.rawValue).sorted(), forKey: Key.enabledFeatures) }
    }

    /// Last active feature, restored when the panel opens (spec L-1, L-2).
    @Published var lastFeature: FeatureID? {
        didSet { defaults.set(lastFeature?.rawValue, forKey: Key.lastFeature) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedDelay = defaults.object(forKey: Key.closeDelay) as? Double
        closeDelay = Self.normalizedDelay(storedDelay ?? Self.defaultCloseDelay)

        let storedOrder = (defaults.stringArray(forKey: Key.featureOrder) ?? []).compactMap(FeatureID.init(rawValue:))
        let missing = FeatureID.allCases.filter { !storedOrder.contains($0) }
        featureOrder = Self.deduplicated(storedOrder) + missing

        if let storedEnabled = defaults.stringArray(forKey: Key.enabledFeatures) {
            let enabled = Set(storedEnabled.compactMap(FeatureID.init(rawValue:)))
            enabledFeatures = enabled.isEmpty ? Set(FeatureID.allCases) : enabled
        } else {
            enabledFeatures = Set(FeatureID.allCases)
        }

        lastFeature = defaults.string(forKey: Key.lastFeature).flatMap(FeatureID.init(rawValue:))
    }

    /// Enabled features in menu-bar order.
    var activeFeatures: [FeatureID] {
        featureOrder.filter(enabledFeatures.contains)
    }

    /// Feature to show when the panel opens: the last one if still enabled, else the first enabled.
    var initialFeature: FeatureID {
        if let lastFeature, enabledFeatures.contains(lastFeature) { return lastFeature }
        return activeFeatures.first ?? .home
    }

    func isEnabled(_ feature: FeatureID) -> Bool {
        enabledFeatures.contains(feature)
    }

    /// Enables or disables a feature. The last enabled feature can't be disabled.
    @discardableResult
    func setEnabled(_ feature: FeatureID, _ enabled: Bool) -> Bool {
        if enabled {
            enabledFeatures.insert(feature)
            return true
        }
        guard enabledFeatures.count > 1 || !enabledFeatures.contains(feature) else { return false }
        enabledFeatures.remove(feature)
        return true
    }

    func moveFeatures(from source: IndexSet, to destination: Int) {
        var order = featureOrder
        let moving = source.sorted().map { order[$0] }
        for index in source.sorted(by: >) { order.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        order.insert(contentsOf: moving, at: max(0, min(insertAt, order.count)))
        featureOrder = order
    }

    static func normalizedDelay(_ value: Double) -> Double {
        let clamped = min(max(value, closeDelayRange.lowerBound), closeDelayRange.upperBound)
        return (clamped * 10).rounded() / 10
    }

    private static func deduplicated(_ list: [FeatureID]) -> [FeatureID] {
        var seen = Set<FeatureID>()
        return list.filter { seen.insert($0).inserted }
    }
}
