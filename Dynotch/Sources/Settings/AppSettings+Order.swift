import Foundation

// MARK: - Feature order and stored values

extension AppSettings {
    /// Moves an enabled feature to a position among the enabled ones (menu bar drag, spec M-6).
    /// Disabled features keep their places in `featureOrder`.
    func moveActiveFeature(_ feature: FeatureID, toActiveIndex index: Int) {
        // The indices are those of the icons shown, so modules left out of the list keep their places.
        moveFeature(feature, to: index, among: listedFeatures)
    }

    /// Moves a feature to a position within `shown` (the menu bar icons or the module strip, spec MS-6);
    /// every other feature keeps its place in `featureOrder`.
    func moveFeature(_ feature: FeatureID, to index: Int, among shown: [FeatureID]) {
        var moved = shown
        guard let from = moved.firstIndex(of: feature) else { return }
        moved.remove(at: from)
        moved.insert(feature, at: min(max(index, 0), moved.count))
        guard moved != shown else { return }
        var remaining = moved.makeIterator()
        featureOrder = featureOrder.map { shown.contains($0) ? (remaining.next() ?? $0) : $0 }
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
        featureOrder.filter(isEnabled)
    }

    /// Feature to show when the panel opens: the last one if still among the modules, else the
    /// first listed one (spec M-18).
    var initialFeature: FeatureID {
        if let lastFeature, isEnabled(lastFeature), listedFeatures.contains(hostFeature(of: lastFeature)) {
            return lastFeature
        }
        return listedFeatures.first ?? activeFeatures.first ?? .home
    }

    /// The enabled modules shown in the top row, the strip and the swipes (spec MU-8).
    var listedFeatures: [FeatureID] {
        activeFeatures.filter { !unlistedFeatures.contains($0) && !isMerged($0) }
    }

    /// Whether a module shows among the modules (spec M-18).
    func isListed(_ feature: FeatureID) -> Bool {
        !unlistedFeatures.contains(feature)
    }

    /// Shows or hides a module among the modules; the last listed one can't be hidden (spec M-18).
    @discardableResult
    func setListed(_ feature: FeatureID, _ listed: Bool) -> Bool {
        if listed {
            unlistedFeatures.remove(feature)
            return true
        }
        guard !listedFeatures.allSatisfy({ $0 == feature }) else { return false }
        unlistedFeatures.insert(feature)
        return true
    }

    // MARK: Merged modules (spec MG-1…MG-8)

    /// A merged module runs while its host is on (spec MG-4); an off module opened from the
    /// swipe-up row runs while it is open (spec QS-15).
    func isEnabled(_ feature: FeatureID) -> Bool {
        let module = hostFeature(of: feature)
        return enabledFeatures.contains(module) || visitingFeature == module
    }

    /// The module's own switch in the settings, without a visit from the swipe-up row (spec QS-15).
    func isSwitchedOn(_ feature: FeatureID) -> Bool {
        enabledFeatures.contains(hostFeature(of: feature))
    }

    /// Batteries and AI Usage are always tabs of their hosts (spec MG-9).
    func isMerged(_ feature: FeatureID) -> Bool {
        feature.mergeHost != nil
    }

    /// The module whose icon stands for `feature`: its host when merged, else itself.
    func hostFeature(of feature: FeatureID) -> FeatureID {
        isMerged(feature) ? feature.mergeHost ?? feature : feature
    }

    /// The host and its merged module, as the tabs of the host's page; nil when nothing is merged into it.
    func mergedTabs(for feature: FeatureID) -> [FeatureID]? {
        let host = hostFeature(of: feature)
        guard let guest = FeatureID.allCases.first(where: { $0.mergeHost == host && isMerged($0) }) else { return nil }
        return [host, guest]
    }

    /// The tab of a merged module picked by hand last (spec MG-10); nil: the host's own.
    func chosenTab(of host: FeatureID) -> FeatureID? {
        (defaults.dictionary(forKey: "mergedTabChoice")?[host.rawValue] as? String).flatMap(FeatureID.init(rawValue:))
    }

    func chooseTab(_ tab: FeatureID, of host: FeatureID) {
        var choices = defaults.dictionary(forKey: "mergedTabChoice") ?? [:]
        choices[host.rawValue] = tab.rawValue
        defaults.set(choices, forKey: "mergedTabChoice")
    }

    func loadModuleOptions() {
        unlistedFeatures = Set((defaults.stringArray(forKey: "unlistedFeatures") ?? []).compactMap(FeatureID.init(rawValue:)))
        showsNowPlaying = defaults.object(forKey: "musicShowsNowPlaying") as? Bool ?? true
        // The Original look is gone (spec D-14e).
        defaults.removeObject(forKey: "refinedDesign")
        glassAccentStrength = Self.stored(defaults, "glassAccentStrength", default: 0.5, in: Self.glassAccentStrengthRange)
        moduleStripHover = defaults.bool(forKey: "moduleStripHover")
        moduleStripHoverDelay = Self.stored(defaults, "moduleStripHoverDelay", default: 0.5, in: Self.moduleStripHoverDelayRange)
    }
}

// MARK: - Small notices (spec PV-66)

extension AppSettings {
    /// The chosen place, or the Wings mode's own one while nothing is chosen.
    var noticePlacement: NoticePlacement {
        get { noticePlacementChoice ?? (hoverPreview ? .beside : .dropDown) }
        set { noticePlacementChoice = newValue }
    }

    /// The small notices stand in the notch's line, beside it (spec PV-66).
    var noticesBeside: Bool { noticePlacement == .beside }
}
