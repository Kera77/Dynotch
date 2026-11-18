import Foundation

// MARK: - Feature order and stored values

extension AppSettings {
    /// Moves an enabled feature to a position among the enabled ones (menu bar drag, spec M-6).
    /// Disabled features keep their places in `featureOrder`.
    func moveActiveFeature(_ feature: FeatureID, toActiveIndex index: Int) {
        var active = activeFeatures
        guard let from = active.firstIndex(of: feature) else { return }
        active.remove(at: from)
        active.insert(feature, at: min(max(index, 0), active.count))
        guard active != activeFeatures else { return }
        var remaining = active.makeIterator()
        featureOrder = featureOrder.map { enabledFeatures.contains($0) ? (remaining.next() ?? $0) : $0 }
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

    /// A stored number, or the default, kept within its range.
    static func stored(_ defaults: UserDefaults, _ key: String, default value: Double, in range: ClosedRange<Double>) -> Double {
        min(max(defaults.object(forKey: key) as? Double ?? value, range.lowerBound), range.upperBound)
    }

    static func deduplicated(_ list: [FeatureID]) -> [FeatureID] {
        var seen = Set<FeatureID>()
        return list.filter { seen.insert($0).inserted }
    }
}
