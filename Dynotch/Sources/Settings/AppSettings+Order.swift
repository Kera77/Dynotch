import Foundation

// MARK: - Feature order and stored values

extension AppSettings {
    /// Moves an enabled feature to a position among the enabled ones (menu bar drag, spec M-6).
    /// Disabled features keep their places in `featureOrder`.
    func moveActiveFeature(_ feature: FeatureID, toActiveIndex index: Int) {
        // The indices are those of the icons shown, so modules left out of the list keep their places.
        let listed = listedFeatures
        var active = listed
        guard let from = active.firstIndex(of: feature) else { return }
        active.remove(at: from)
        active.insert(feature, at: min(max(index, 0), active.count))
        guard active != listed else { return }
        var remaining = active.makeIterator()
        featureOrder = featureOrder.map { listed.contains($0) ? (remaining.next() ?? $0) : $0 }
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

// MARK: - Which modules show

extension AppSettings {
    /// Enabled features in menu-bar order.
    var activeFeatures: [FeatureID] {
        featureOrder.filter(enabledFeatures.contains)
    }

    /// Feature to show when the panel opens: the last one if still enabled, else the first enabled.
    var initialFeature: FeatureID {
        if let lastFeature, enabledFeatures.contains(lastFeature) { return lastFeature }
        return listedFeatures.first ?? activeFeatures.first ?? .home
    }

    /// The enabled modules shown in the top row, the strip and the swipes (spec MU-8).
    var listedFeatures: [FeatureID] {
        activeFeatures.filter { !unlistedFeatures.contains($0) }
    }

    func loadModuleOptions() {
        unlistedFeatures = Set((defaults.stringArray(forKey: "unlistedFeatures") ?? []).compactMap(FeatureID.init(rawValue:)))
        showsNowPlaying = defaults.object(forKey: "musicShowsNowPlaying") as? Bool ?? true
    }
}
